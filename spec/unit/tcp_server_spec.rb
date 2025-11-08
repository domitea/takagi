# frozen_string_literal: true

RSpec.describe 'Takagi TCP Server' do
  def encode_tcp_frame(data)
    return ''.b if data.empty?

    first_byte = data.getbyte(0)
    tkl = first_byte & 0x0F

    # Current implementation: Length = size of (Options + Payload)
    code_size = 1
    payload_length = [data.bytesize - 1 - code_size - tkl, 0].max

    body = data.byteslice(1, data.bytesize - 1) || ''.b

    if payload_length <= 12
      new_first_byte = (payload_length << 4) | tkl
      [new_first_byte].pack('C') + body
    elsif payload_length <= 268
      new_first_byte = (13 << 4) | tkl
      extension = payload_length - 13
      [new_first_byte, extension].pack('CC') + body
    elsif payload_length <= 65_804
      new_first_byte = (14 << 4) | tkl
      extension = payload_length - 269
      [new_first_byte].pack('C') + [extension].pack('n') + body
    else
      new_first_byte = (15 << 4) | tkl
      extension = payload_length - 65_805
      [new_first_byte].pack('C') + [extension].pack('N') + body
    end
  end

  def read_tcp_message(socket)
    socket.setsockopt(Socket::SOL_SOCKET, Socket::SO_RCVTIMEO, [5, 0].pack('l_2'))

    first_byte_data = socket.read(1)
    return nil if first_byte_data.nil? || first_byte_data.empty?

    first_byte = first_byte_data.unpack1('C')
    len_nibble = (first_byte >> 4) & 0x0F
    tkl = first_byte & 0x0F

    length = case len_nibble
             when 0..12
               len_nibble
             when 13
               ext = socket.read(1)
               return nil unless ext
               ext.unpack1('C') + 13
             when 14
               ext = socket.read(2)
               return nil unless ext
               ext.unpack1('n') + 269
             when 15
               ext = socket.read(4)
               return nil unless ext
               ext.unpack1('N') + 65_805
             end

    # Current implementation: length is Options + Payload
    # Need to read: Code (1 byte) + Token (tkl bytes) + Options + Payload (length bytes)
    bytes_to_read = 1 + tkl + length
    data = socket.read(bytes_to_read)
    return nil unless data

    first_byte_data + data
  end

  it 'handles GET requests over TCP' do
    port = find_free_port
    server = Takagi::Base.spawn!(port: port, protocols: [:tcp])
    client = TCPSocket.new('127.0.0.1', port)

    # Create TCP-formatted message using Outbound
    request = Takagi::Message::Outbound.new(
      code: 1,  # GET
      payload: nil,
      token: '12345678',
      options: {11 => ['ping']},  # Uri-Path
      transport: :tcp
    )
    data = request.to_bytes(transport: :tcp)
    framed_data = encode_tcp_frame(data)
    client.write(framed_data)

    response = read_tcp_message(client)
    client.close

    inbound = Takagi::Message::Inbound.new(response, transport: :tcp)
    expect(inbound.payload).to include('Pong')
  ensure
    server.shutdown!
  end
end
