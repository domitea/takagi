# frozen_string_literal: true

require 'socket'
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
      message = Takagi::Message::Request.new(method: method, uri: uri, payload: payload)

      socket = TCPSocket.new(uri.host, uri.port || 5683)
      data = message.to_bytes

      # RFC 8323: CoAP over TCP uses length-prefixed framing
      socket.write([data.bytesize].pack('n') + data)

      # Read response with length prefix
      len_bytes = socket.read(2)
      length = len_bytes.unpack1('n')
      response = socket.read(length)

      socket.close

      deliver_response(response, &callback)
    rescue StandardError => e
      puts "TakagiTcpClient Error: #{e.message}"
    end
  end
end
