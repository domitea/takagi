# frozen_string_literal: true

RSpec.describe Takagi::Observer::Client do
  let(:uri) { 'coap://127.0.0.1:5683/foo' }
  let(:client) { described_class.new(uri) }

  it 'sends observe request and listens for notifications' do
    fake_socket = instance_double(UDPSocket)
    allow(UDPSocket).to receive(:new).and_return(fake_socket)
    allow(fake_socket).to receive(:send)
    allow(fake_socket).to receive(:recvfrom_nonblock).and_return([
                                                                   Takagi::Message::Outbound.new(
                                                                     code: '2.05',
                                                                     payload: 'Hello World',
                                                                     token: client.instance_variable_get(:@token)
                                                                   ).to_bytes, ['127.0.0.1', 5683]
                                                                 ])

    received = nil
    client.on_notify { |payload, _| received = payload }
    thread = client.subscribe

    Timeout.timeout(1) do
      sleep 0.05 until received
    end

    expect(fake_socket).to have_received(:send)
    expect(received).to eq('Hello World')

    thread.kill
  end
end