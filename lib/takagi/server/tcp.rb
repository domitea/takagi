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
          break if @shutdown_called

          begin
            client = @server.accept
          rescue IOError, SystemCallError => e
            @logger.debug "TCP server accept loop exiting: #{e.message}" if @shutdown_called
            break
          end

          Thread.new(client) { |sock| handle_connection(sock) }
        end
      end

      def shutdown!
        return if @shutdown_called

        @shutdown_called = true
        @watcher.stop
        @server.close if @server && !@server.closed?
      end

      private

      def handle_connection(sock)
        loop do
          inbound_request = read_request(sock)
          break unless inbound_request

          response = build_response(inbound_request)
          transmit_response(sock, response)
        end
      rescue StandardError => e
        @logger.error "TCP handle_connection failed: #{e.message}"
      ensure
        sock.close
      end

      def read_request(sock)
        len_bytes = sock.read(2)
        return unless len_bytes

        length = len_bytes.unpack1('n')
        data = sock.read(length)
        return unless data

        Takagi::Message::Inbound.new(data)
      end

      def build_response(inbound_request)
        result = @middleware_stack.call(inbound_request)
        case result
        when Takagi::Message::Outbound
          result
        when Hash
          inbound_request.to_response('2.05 Content', result)
        else
          inbound_request.to_response('5.00 Internal Server Error', { error: 'Internal Server Error' })
        end
      end

      def transmit_response(sock, response)
        bytes = response.to_bytes
        sock.write([bytes.bytesize].pack('n') + bytes)
      end
    end
  end
end
