# frozen_string_literal: true

RSpec.describe Takagi::Observer::Sender do
  it 'sends CoAP packet to subscriber' do
    port = find_free_port
    fake_server = UDPSocket.new
    fake_server.bind('127.0.0.1', port)

    socket = UDPSocket.new
    Takagi::Network::UdpSender.instance.setup(socket: socket)

    subscriber = { address: '127.0.0.1', port: port, token: 'abc' }

    sender = described_class.new
    sender.send_packet(subscriber, 'Hello')

    data, _addr = fake_server.recvfrom(1024)
    expect(data).to include('Hello')

    fake_server.close
    socket.close
  end
end