# frozen_string_literal: true

require_relative '../response_builder'

module Takagi
  module Server
    # Handles incoming UDP messages on behalf of the master Udp server.
    class UdpWorker
      def initialize(socket:, middleware_stack:, **options)
        @socket = socket
        @middleware_stack = middleware_stack
        @sender = options.fetch(:sender)
        @logger = options.fetch(:logger)
        @port = options.fetch(:port)
        @threads = options.fetch(:threads)
      end

      def run
        queue = Queue.new
        Array.new(@threads) { spawn_thread(queue) }

        @logger.debug "[Worker PID: #{Process.pid}] Listening on CoAP://0.0.0.0:#{@port} with #{@threads} threads"
        process_loop(queue)
      end

      private

      def process_loop(queue)
        loop do
          next unless @socket.wait_readable(1)

          queue << @socket.recvfrom(1024)
        end
      rescue Interrupt
        @logger.debug "[Worker PID: #{Process.pid}] Shutting down..."
        exit(0)
      end

      def spawn_thread(queue)
        Thread.new do
          loop do
            request, addr = queue.pop
            handle_request(request, addr)
          end
        end
      end

      def handle_request(request, addr)
        inbound_request = Takagi::Message::Inbound.new(request)
        log_inbound_request(inbound_request)

        immediate = immediate_response(inbound_request)
        return transmit(immediate, addr) if immediate

        result = @middleware_stack.call(inbound_request)
        log_middleware_result(result)
        response = build_response(inbound_request, result)
        transmit(response, addr)
      rescue StandardError => e
        @logger.error "Handle_request failed: #{e.message}"
      end

      def log_inbound_request(inbound_request)
        @logger.debug "Code: #{inbound_request.code}"
        @logger.debug "Method: #{inbound_request.method}"
      end

      def immediate_response(inbound_request)
        if inbound_request.type == 1 && inbound_request.method == 'EMPTY'
          return Takagi::Message::Outbound.new(
            code: '0.00',
            payload: '',
            token: '',
            message_id: inbound_request.message_id,
            type: 3
          )
        end

        return unless inbound_request.code.zero? && inbound_request.method == 'EMPTY'

        Takagi::Message::Outbound.new(
          code: '0.00',
          payload: '',
          token: inbound_request.token,
          message_id: inbound_request.message_id,
          type: 2
        )
      end

      def log_middleware_result(result)
        @logger.debug "Middleware result class: #{result.class}"
        @logger.debug "Middleware result inspect: #{result.inspect}"
        return unless result.is_a?(Hash)

        @logger.debug "Hash response keys: #{result.keys}"
        result.each do |key, value|
          @logger.debug "Key: #{key.inspect} => #{value.inspect} (#{value.class})"
        end
      end

      def build_response(inbound_request, result)
        ResponseBuilder.build(inbound_request, result, logger: @logger)
      end

      def transmit(response, addr)
        @sender.transmit(response, addr[3], addr[1])
      end
    end
  end
end
