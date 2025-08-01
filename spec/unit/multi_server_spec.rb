# frozen_string_literal: true

RSpec.describe 'Takagi Multi Protocol Server' do
  it 'handles requests over both UDP and TCP' do
    port = find_free_port
    server = Takagi::Base.spawn!(port: port, protocols: [:udp, :tcp])

    udp_socket = UDPSocket.new
    request = Takagi::Message::Request.new(method: :get, uri: URI('coap://localhost/ping'))
    udp_socket.send(request.to_bytes, 0, '127.0.0.1', port)
    response, = udp_socket.recvfrom(1024)
    inbound_udp = Takagi::Message::Inbound.new(response)
    expect(inbound_udp.payload).to include('Pong')

    tcp_client = TCPSocket.new('127.0.0.1', port)
    data = request.to_bytes
    tcp_client.write([data.bytesize].pack('n') + data)
    len_bytes = tcp_client.read(2)
    length = len_bytes.unpack1('n')
    tcp_response = tcp_client.read(length)
    tcp_client.close
    inbound_tcp = Takagi::Message::Inbound.new(tcp_response)
    expect(inbound_tcp.payload).to include('Pong')
  ensure
    server.shutdown!
  end
end
