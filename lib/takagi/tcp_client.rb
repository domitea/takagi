# frozen_string_literal: true

require 'uri'
require 'socket'

module Takagi
  # Minimal CoAP-over-TCP client used for smoke testing Takagi servers.
  class TcpClient
    attr_reader :server_uri, :timeout, :callbacks

    def initialize(server_uri, timeout: 5)
      @server_uri = URI(server_uri)
      @timeout = timeout
      @callbacks = {}
    end

    def on(event, &callback)
      @callbacks[event] = callback
    end

    def get(path, &block)
      request(:get, path, nil, &block)
    end

    def post(path, payload, &block)
      request(:post, path, payload, &block)
    end

    def put(path, payload, &block)
      request(:put, path, payload, &block)
    end

    def delete(path, &block)
      request(:delete, path, nil, &block)
    end

    private

    def request(method, path, payload = nil, &callback)
      uri = URI.join(server_uri.to_s, path)
      message = Takagi::Message::Request.new(method: method, uri: uri, payload: payload)

      begin
        socket = TCPSocket.new(uri.host, uri.port || 5683)
        data = message.to_bytes
        socket.write([data.bytesize].pack('n') + data)
        len_bytes = socket.read(2)
        length = len_bytes.unpack1('n')
        response = socket.read(length)
        socket.close

        if callback
          callback.call(response)
        elsif @callbacks[:response]
          @callbacks[:response].call(response)
        else
          puts response
        end
      rescue StandardError => e
        puts "TakagiTcpClient Error: #{e.message}"
      end
    end
  end
end
