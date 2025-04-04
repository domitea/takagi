# frozen_string_literal: true

require 'spec_helper'
require 'socket'
require 'timeout'

RSpec.describe Takagi::Observer::Client do
  let(:server_port) { find_free_port }
  let(:server_socket) { UDPSocket.new }
  let(:notify_payload) { '{"temp":22.5}' }
  let(:uri) { "coap://localhost:#{server_port}/sensors/temp" }

  before do
    server_socket.bind('0.0.0.0', server_port)
  end

  after do
    server_socket.close
  end

  it 'sends observe request and receives notification' do
    queue = Queue.new

    server_thread = Thread.new do
      data, addr = server_socket.recvfrom(1024)
      request = Takagi::Message::Inbound.new(data)

      expect(request.options[6]&.bytes&.first).to eq(0) # Observe option must be 0

      response = Takagi::Message::Outbound.new(
        code: 69,
        payload: notify_payload,
        token: request.token,
        type: 2
      )
      sleep 0.1
      server_socket.send(response.to_bytes, 0, addr[3], addr[1])
    end

    client = Takagi::Observer::Client.new(uri)
    client.on_notify do |payload, _|
      queue.push(payload)
    end

    client.subscribe

    result = nil
    Timeout.timeout(2) { result = queue.pop }

    expect(result).to eq(notify_payload)

    server_thread.kill
  end
end

RSpec.describe Takagi::Reactor do
  let(:reactor) { Takagi::Reactor.new }

  it 'registers remote observe' do
    uri = "coap://localhost:5683/sensors/temp"
    handler = proc { |_payload, _inbound| }

    expect(Takagi.logger).to receive(:info).with("Observing remote resource: #{uri}")
    reactor.observe(uri, &handler)

    expect(reactor.instance_variable_get(:@observes).size).to eq(1)
    expect(reactor.instance_variable_get(:@observes).first[:uri]).to eq(uri)
  end

  it 'notifies observer handlers when triggered' do
    uri = "coap://localhost:5683/sensors/temp"
    queue = Queue.new

    reactor.observe(uri) do |payload, _|
      queue.push(payload)
    end

    reactor.trigger_observe(uri, '{"temp":30.0}')

    result = nil
    Timeout.timeout(2) { result = queue.pop }

    expect(result).to eq('{"temp":30.0}')
  end
end

RSpec.describe 'Takagi Observe End-to-End' do
  let(:queue) { Queue.new }
  port = find_free_port

  before(:all) do
    @server_pid = fork do
        class TestApp < Takagi::Base
          reactor do
            observable "/sensors/temp" do
              { temp: 42.0 }
            end
          end
        end

        TestApp.run!(port: ENV['PORT'] || port)
      end
      sleep 1
  end

  after(:all) do
    Process.kill('INT', @server_pid)
    Process.wait(@server_pid)
  end

  it 'observes server observable' do
    client = Takagi::Observer::Client.new("coap://localhost:#{port}/sensors/temp")
    client.on_notify do |payload, _|
      queue.push(payload)
    end

    client.subscribe

    result = nil
    Timeout.timeout(5) { result = queue.pop }

    expect(result).to include("temp")
  end
end