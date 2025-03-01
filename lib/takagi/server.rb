# frozen_string_literal: true

require 'yaml'

module Takagi
  class Server
    def initialize(port: 5683, config_file: "middleware_config.yml")
      @port = port
      @socket = UDPSocket.new
      @socket.bind("0.0.0.0", @port)
      @middlewares = Takagi::MiddlewareStack.load_from_config(config_file)
      Initializer.run!
    end

    def run!
      puts "Takagi running on CoAP://0.0.0.0:#{@port}"

      loop do
        data, addr = @socket.recvfrom(1024)
        Ractor.new(data, addr, @middlewares) do |data, addr, middlewares|
          request = Message::Inbound.new(data)
          response = middlewares.call(request)
          @socket.send(response.to_bytes, 0, addr[3], addr[1])
        end
      end
    end

    def call(request)
      request.to_response(code: 69, payload: { message: "Pong" })
    end
  end
end
