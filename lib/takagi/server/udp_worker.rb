# frozen_string_literal: true

require_relative '../response_builder'
require_relative '../message/deduplication_cache'

module Takagi
  module Server
    # Handles incoming UDP messages on behalf of the master Udp server.
    class UdpWorker
      def initialize(socket:, middleware_stack:, **options)
        @socket = socket
        @middleware_stack = middleware_stack
        @router = options.fetch(:router, nil)
        @sender = options.fetch(:sender)
        @logger = options.fetch(:logger)
        @port = options.fetch(:port)
        @threads = options.fetch(:threads)
        @dedup_cache = Takagi::Message::DeduplicationCache.new
      end

      def run
        @shutdown = false
        trap('TERM') { @shutdown = true }
        trap('INT') { @shutdown = true }

        queue = Queue.new
        Array.new(@threads) { spawn_thread(queue) }

        @logger.debug "[Worker PID: #{Process.pid}] Listening on CoAP://0.0.0.0:#{@port} with #{@threads} threads"
        process_loop(queue)
      end

      private

      def process_loop(queue)
        loop do
          break if @shutdown

          next unless @socket.wait_readable(0.1)

          queue << @socket.recvfrom(1024)
        end
        @logger.debug "[Worker PID: #{Process.pid}] Shutting down..."
        exit(0)
      rescue Interrupt, SignalException
        @logger.debug "[Worker PID: #{Process.pid}] Interrupted, shutting down..."
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

        # RFC 7252 §4.4: Check for duplicate messages
        source_endpoint = "#{addr[3]}:#{addr[1]}"
        if inbound_request.type.zero? # CON message
          cached_response = @dedup_cache.check_duplicate(inbound_request.message_id, source_endpoint)
          if cached_response
            @logger.debug "Duplicate CON detected (MID: #{inbound_request.message_id}), resending cached response"
            return @sender.transmit(cached_response, addr[3], addr[1])
          end
        end

        immediate = immediate_response(inbound_request)
        return transmit(immediate, addr) if immediate

        # Delegate to controller's thread pool if available
        delegate_to_controller_pool(inbound_request, addr)
      rescue StandardError => e
        @logger.error "Handle_request failed: #{e.message}"
      end

      def delegate_to_controller_pool(inbound_request, addr)
        # Find which controller handles this path
        path = inbound_request.uri.path
        controller_class = find_controller_for_path(path)

        if controller_class&.workers_running?
          # Delegate to controller's thread pool
          @logger.debug "Delegating #{path} to #{controller_class.name} worker pool"
          source_endpoint = "#{addr[3]}:#{addr[1]}"

          controller_class.schedule do
            process_request(inbound_request, addr, source_endpoint)
          end
        else
          # No controller pool available - process synchronously (backward compatible)
          @logger.debug "Processing #{path} synchronously (no controller pool)"
          source_endpoint = "#{addr[3]}:#{addr[1]}"
          process_request(inbound_request, addr, source_endpoint)
        end
      end

      def process_request(inbound_request, addr, source_endpoint)
        result = @middleware_stack.call(inbound_request)
        log_middleware_result(result)
        response = build_response(inbound_request, result)

        # Cache CON responses for duplicate detection
        if inbound_request.type.zero? && response
          response_data = response.to_bytes
          @dedup_cache.store_response(inbound_request.message_id, source_endpoint, response_data)
        end

        transmit(response, addr)
      rescue StandardError => e
        @logger.error "Process_request failed: #{e.message}"
      end

      def find_controller_for_path(path)
        # If using a CompositeRouter, find the controller
        # Otherwise return nil (backward compatible with single Router)
        return nil unless @router&.respond_to?(:find_controller_for_path)

        @router.find_controller_for_path(path)
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
