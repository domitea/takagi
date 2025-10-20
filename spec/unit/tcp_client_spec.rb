# frozen_string_literal: true

RSpec.describe Takagi::TcpClient do
  it 'sends request and receives response over TCP' do
    port = find_free_port
    server = Takagi::Base.spawn!(port: port, protocols: [:tcp])
    client = described_class.new("coap+tcp://127.0.0.1:#{port}")

    response = nil
    client.get('/ping') { |res| response = res }

    inbound = Takagi::Message::Inbound.new(response)
    expect(inbound.payload).to include('Pong')
  ensure
    server.shutdown!
  end
end
