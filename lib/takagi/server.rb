# frozen_string_literal: true

require 'yaml'

module Takagi
  class Server
    def initialize(port: 5683, worker_processes: 2, worker_threads: 5)
      @port = port
      @worker_processes = worker_processes
      @worker_threads = worker_threads
      @middleware_stack = Takagi::MiddlewareStack.instance
      @router = Takagi::Router.instance

      Initializer.run! # Load any initialization logic

      @socket = UDPSocket.new
      @socket.bind('0.0.0.0', @port)
    end

    # Starts the server with multiple worker processes
    def run!
      puts "Starting Takagi server with #{@worker_processes} processes and #{@worker_threads} threads per process..."
      puts "run #{@router.all_routes}"
      @worker_processes.times do
        puts "process with #{@router.all_routes}"
        fork do
          start_worker_process(@socket)
        end
      end

      trap("INT") { shutdown! }
      Process.waitall
    end

    # Gracefully shuts down all workers
    def shutdown!
      puts "[Server] Shutting down all workers..."

      if @workers.is_a?(Array)
        @workers.each { |worker| worker.exit if worker.alive? }
      end

      Process.kill("TERM", 0) # Sends SIGTERM to all worker processes
      puts "[Server] Shutdown complete."
      exit(0)
    end


    private

    # Starts a worker process that listens for incoming requests
    # @param socket [UDPSocket] The shared UDP socket
    def start_worker_process(socket)
      queue = Queue.new
      @workers = Array.new(@worker_threads) { start_thread_worker(queue, socket) }

      puts "[Worker PID: #{Process.pid}] Listening on CoAP://0.0.0.0:#{@port} with #{@worker_threads} threads"

      loop do
        if socket.wait_readable(1)
          request, addr = socket.recvfrom(1024)
          queue << [request, addr]
        end
      end
    rescue Interrupt
      puts "[Worker PID: #{Process.pid}] Shutting down..."
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
      result = @middleware_stack.call(inbound_request)

      response =
        if result.is_a?(Takagi::Message::Outbound)
          result
        elsif result.is_a?(Hash)
          puts "returned #{result} as reponse"
          inbound_request.to_response("2.05 Content", result)
        else
          puts "[Warning] Middleware returned non-Hash: #{result.inspect}"
          inbound_request.to_response("5.00 Internal Server Error", { error: "Internal Server Error" })
        end

      socket.send(response.to_bytes, 0, addr[3], addr[1])
    rescue => e
      puts "[Error] handle_request failed: #{e.message}"
    end
  end
end
