# frozen_string_literal: true

module Takagi
  # Server class for serving
  class Server
    def initialize(port: 5683, worker_processes: 2, worker_threads: 2)
      @port = port
      @worker_processes = worker_processes
      @worker_threads = worker_threads
      @middleware_stack = Takagi::MiddlewareStack.instance
      @router = Takagi::Router.instance
      @logger = Takagi.logger

      Initializer.run! # Load any initialization logic

      @socket = UDPSocket.new
      @socket.bind('0.0.0.0', @port)
    end

    # Starts the server with multiple worker processes
    def run!
      @logger.info "Starting Takagi server with #{@worker_processes} processes and #{@worker_threads} threads per process..."
      @logger.debug "run #{@router.all_routes}"

      @worker_pids = []
      @worker_processes.times do
        @logger.debug "process with #{@router.all_routes}"
        pid = fork do
          Process.setproctitle('takagi-worker')
          start_worker_process(@socket)
        end
        @worker_pids << pid
      end

      trap('INT') { shutdown! }
      Process.waitall
    end

    # Gracefully shuts down all workers
    # TODO: Implement better logging with signal handling.
    def shutdown!
      return if @shutdown_called

      @shutdown_called = true

      #@logger.info '[Server] Shutting down all workers...'

      if @socket && !@socket.closed?
        begin
          @socket.close
        rescue StandardError
          nil
        end
        #@logger.info '[Server] Socket closed.'
      end

      if @worker_pids.is_a?(Array)
        @worker_pids.each do |pid|
          Process.kill('TERM', pid)
        rescue Errno::ESRCH
          # @logger.debug "[Server] Process #{pid} already exited"
        end
      end

      #@logger.info '[Server] Shutdown complete.'

      return if ENV['RACK_ENV'] == 'test' || defined?(RSpec)

      exit(0)
    end

    private

    # Starts a worker process that listens for incoming requests
    # @param socket [UDPSocket] The shared UDP socket
    def start_worker_process(socket)
      queue = Queue.new
      @workers = Array.new(@worker_threads) { start_thread_worker(queue, socket) }

      @logger.debug "[Worker PID: #{Process.pid}] Listening on CoAP://0.0.0.0:#{@port} with #{@worker_threads} threads"

      loop do
        if socket.wait_readable(1)
          request, addr = socket.recvfrom(1024)
          queue << [request, addr]
        end
      end
    rescue Interrupt
      @logger.debug "[Worker PID: #{Process.pid}] Shutting down..."
      exit(0)
    end

    # Starts a thread worker that processes requests from the queue
    # @param queue [Queue] Shared request queue
    # @param socket [UDPSocket] UDP socket for response sending
    def start_thread_worker(queue, socket)
      Thread.new do
        loop do
          request, addr = queue.pop
          handle_request(request, addr, socket)
        end
      end
    end

    # Handles an incoming request by passing it through the middleware stack
    # @param request [String] Raw request data
    # @param addr [Array] Address details of the sender
    # @param socket [UDPSocket] UDP socket for sending responses
    def handle_request(request, addr, socket)
      inbound_request = Takagi::Message::Inbound.new(request)
      @logger.debug "Code: #{inbound_request.code}"
      @logger.debug "Method: #{inbound_request.method}"

      # Unexpected NON → RST
      if inbound_request.type == 1 && inbound_request.method == 'EMPTY'
        response = Takagi::Message::Outbound.new(code: '0.00', payload: '', token: '', message_id: inbound_request.message_id, type: 3)
        socket.send(response.to_bytes, 0, addr[3], addr[1])
        return
      end

      if inbound_request.code.zero? && inbound_request.method == 'EMPTY'
        # RFC 7252: Empty Confirmable → reply with empty ACK
        response = Takagi::Message::Outbound.new(code: '0.00', payload: '', token: inbound_request.token,
                                                 message_id: inbound_request.message_id, type: 2)
        socket.send(response.to_bytes, 0, addr[3], addr[1])
        return
      end

      result = @middleware_stack.call(inbound_request)

      @logger.debug "Middleware result class: #{result.class}"
      @logger.debug "Middleware result inspect: #{result.inspect}"

      if result.is_a?(Hash)
        @logger.debug "Hash response keys: #{result.keys}"
        result.each do |k, v|
          @logger.debug "Key: #{k.inspect} => #{v.inspect} (#{v.class})"
        end
      end

      response =
        if result.is_a?(Takagi::Message::Outbound)
          result
        elsif result.is_a?(Hash)
          @logger.debug "Returned #{result} as reponse"
          inbound_request.to_response('2.05 Content', result)
        else
          @logger.warn "Middleware returned non-Hash: #{result.inspect}"
          inbound_request.to_response('5.00 Internal Server Error', { error: 'Internal Server Error' })
        end

      socket.send(response.to_bytes, 0, addr[3], addr[1])
    rescue StandardError => e
      @logger.error "Handle_request failed: #{e.message}"
    end
  end
end
