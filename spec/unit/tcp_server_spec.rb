# frozen_string_literal: true

RSpec.describe 'Takagi TCP Server' do
  it 'handles GET requests over TCP' do
    port = find_free_port
    server = Takagi::Base.spawn!(port: port, protocols: [:tcp])
    client = TCPSocket.new('127.0.0.1', port)

    request = Takagi::Message::Request.new(method: :get, uri: URI('coap://localhost/ping'))
    data = request.to_bytes
    client.write([data.bytesize].pack('n') + data)

    len_bytes = client.read(2)
    length = len_bytes.unpack1('n')
    response = client.read(length)
    client.close

    inbound = Takagi::Message::Inbound.new(response)
    expect(inbound.payload).to include('Pong')
  ensure
    server.shutdown!
  end
end
