# frozen_string_literal: true

require 'socket'
require 'securerandom'
require_relative 'client_base'

module Takagi
  # CoAP-over-TCP client for testing Takagi servers with TCP transport.
  #
  # This client implements CoAP over TCP (RFC 8323) with automatic length framing.
  # Unlike the UDP client, TCP provides reliable delivery so no retransmission
  # manager is needed.
  #
  # @example Basic usage with auto-close (recommended)
  #   Takagi::TcpClient.open('coap+tcp://localhost:5683') do |client|
  #     client.get('/temperature')
  #   end
  #
  # @example Manual lifecycle management
  #   client = Takagi::TcpClient.new('coap+tcp://localhost:5683')
  #   begin
  #     client.get('/temperature')
  #   ensure
  #     client.close
  #   end
  class TcpClient < ClientBase
    protected

    def request(method, path, payload = nil, &callback)
      uri = URI.join(server_uri.to_s, path)

      # Build TCP-formatted message
      # Extract URI path segments
      path_segments = uri.path.split('/').reject(&:empty?)
      options = {}
      path_segments.each_with_index do |segment, _index|
        options[11] ||= []
        options[11] << segment
      end

      # Convert method symbol to CoAP code
      code = case method.to_sym
             when :get then 1
             when :post then 2
             when :put then 3
             when :delete then 4
             else 1
             end

      # Generate token
      token = SecureRandom.hex(4)

      # Create TCP message using Outbound
      message = Takagi::Message::Outbound.new(
        code: code,
        payload: payload,
        token: token,
        options: options,
        transport: :tcp
      )

      socket = TCPSocket.new(uri.host, uri.port || 5683)
      data = message.to_bytes(transport: :tcp)

      # RFC 8323: CoAP over TCP uses variable-length framing
      framed_data = encode_tcp_frame(data)
      socket.write(framed_data)

      # Read response with RFC 8323 framing
      response = read_tcp_message(socket)

      socket.close

      deliver_response(response, &callback) if response
    rescue StandardError => e
      puts "TakagiTcpClient Error: #{e.message}"
      puts e.backtrace.join("\n")
    end

    private

    # Read TCP message with RFC 8323 §3.3 variable-length framing
    def read_tcp_message(socket)
      # Set read timeout to prevent indefinite blocking
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

    # Encode TCP frame - Length = size of (Options + Payload)
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
  end
end
