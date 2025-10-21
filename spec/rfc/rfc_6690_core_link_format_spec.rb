# frozen_string_literal: true

require 'socket'
require 'spec_helper'

RSpec.describe 'Takagi RFC 6690 Resource Discovery' do
  before(:all) do
    @previous_server_name = Takagi.config.server_name
    Takagi.config.server_name = 'Takagi Testbed'

    Takagi::Base.get '/spec-temp', metadata: { rt: 'sensor.temp', if: 'core.s', title: 'Temperature' } do
      { temp: 22.5 }
    end

    Takagi::Base.observable '/spec-alerts', metadata: { title: 'Alerts', rt: 'sensor.alert' } do
      { alert: true }
    end

    Takagi::Base.get '/spec-dump', metadata: { title: 'Dump', rt: 'sensor.dump', sz: 1024 } do
      { dump: 'ok' }
    end

    port = find_free_port
    @server = Takagi::Base.spawn!(port: port)
    @client = UDPSocket.new
    @server_address = ['127.0.0.1', port]
  end

  after(:all) do
    @server.shutdown!
    @client.close
    Takagi.config.server_name = @previous_server_name
  end

  it 'returns CoRE Link Format listing registered resources' do
    response = send_coap_request(:con, :get, '/.well-known/core')
    parsed = Takagi::Message::Inbound.new(response)

    expect(parsed.code).to eq(69)
    expect(parsed.options[12].bytes.first).to eq(40)

    links = parsed.payload.split(',')
    expect(links.any? { |link| link.include?('</ping>') && link.include?('rt="core#endpoint"') }).to be(true)
    expect(links.any? { |link| link.include?('</spec-temp>') && link.include?('rt="sensor.temp"') }).to be(true)
    expect(links.any? { |link| link.include?('</spec-alerts>') && link.include?(';obs') }).to be(true)
  end

  it 'filters resources by resource type' do
    response = send_coap_request(:con, :get, '/.well-known/core', nil, query: { 'rt' => 'sensor.temp' })
    parsed = Takagi::Message::Inbound.new(response)

    links = parsed.payload.split(',')
    expect(links).to all(include('</spec-temp>'))
  end

  it 'filters observable resources using the obs query' do
    response = send_coap_request(:con, :get, '/.well-known/core', nil, query: 'obs')
    parsed = Takagi::Message::Inbound.new(response)

    links = parsed.payload.split(',')
    expect(links).to all(include('</spec-alerts>'))
  end

  it 'filters resources by title attribute' do
    response = send_coap_request(:con, :get, '/.well-known/core', nil, query: { 'title' => 'Alerts' })
    parsed = Takagi::Message::Inbound.new(response)

    links = parsed.payload.split(',')
    expect(links).to all(include('</spec-alerts>'))
    expect(links).to all(include('title="Alerts"'))
  end

  it 'filters resources by size attribute' do
    response = send_coap_request(:con, :get, '/.well-known/core', nil, query: { 'sz' => '1024' })
    parsed = Takagi::Message::Inbound.new(response)

    links = parsed.payload.split(',')
    expect(links).to all(include('</spec-dump>'))
    expect(links).to all(include(';sz=1024'))
  end

  it 'exposes the configured server name in the discovery payload' do
    response = send_coap_request(:con, :get, '/.well-known/core')
    parsed = Takagi::Message::Inbound.new(response)

    links = parsed.payload.split(',')
    expect(links.any? { |link| link.include?('</>') && link.include?('title="Takagi Testbed"') }).to be(true)
  end

  it 'includes sz attributes when provided by route metadata' do
    response = send_coap_request(:con, :get, '/.well-known/core')
    parsed = Takagi::Message::Inbound.new(response)

    links = parsed.payload.split(',')
    expect(links.any? { |link| link.include?('</spec-dump>') && link.include?(';sz=1024') }).to be(true)
  end
end
