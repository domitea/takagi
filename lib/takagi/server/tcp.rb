# frozen_string_literal: true

require 'socket'

module Takagi
  module Server
    # TCP server implementation for CoAP over TCP
    class Tcp
    def initialize(port: 5683, worker_threads: 2)
      @port = port
      @worker_threads = worker_threads
      @middleware_stack = Takagi::MiddlewareStack.instance
      @router = Takagi::Router.instance
      @logger = Takagi.logger
      @watcher = Takagi::Observer::Watcher.new(interval: 1)

      Initializer.run!

      @server = TCPServer.new('0.0.0.0', @port)
      @sender = Takagi::Network::TcpSender.instance
    end

    def run!
      @logger.info "Starting Takagi TCP server on port #{@port}"
      @workers = []
      @watcher.start
      trap('INT') { shutdown! }

      loop do
        client = @server.accept
        Thread.new(client) { |sock| handle_connection(sock) }
      end
    end

    def shutdown!
      return if @shutdown_called

      @shutdown_called = true
      @watcher.stop
      @server.close if @server
    end

    private

    def handle_connection(sock)
      loop do
        len_bytes = sock.read(2)
        break unless len_bytes

        length = len_bytes.unpack1('n')
        data = sock.read(length)
        break unless data

        inbound_request = Takagi::Message::Inbound.new(data)
        result = @middleware_stack.call(inbound_request)
        response = if result.is_a?(Takagi::Message::Outbound)
                     result
                   elsif result.is_a?(Hash)
                     inbound_request.to_response('2.05 Content', result)
                   else
                     inbound_request.to_response('5.00 Internal Server Error', { error: 'Internal Server Error' })
                   end
        bytes = response.to_bytes
        sock.write([bytes.bytesize].pack('n') + bytes)
      end
    rescue StandardError => e
      @logger.error "TCP handle_connection failed: #{e.message}"
    ensure
      sock.close
    end
  end
end
end
