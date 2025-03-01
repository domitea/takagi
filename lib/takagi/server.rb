# frozen_string_literal: true

require 'yaml'

module Takagi
  class Server
    def initialize(port: 5683, worker_processes: 2, worker_threads: 10)
      @port = port
      @worker_processes = worker_processes
      @worker_threads = worker_threads
      @middleware_stack = Takagi::MiddlewareStack.load_from_config("")
      Initializer.run!

      @socket = UDPSocket.new
      @socket.bind('0.0.0.0', @port)
    end

    def run!
      puts "Starting Takagi server with #{@worker_processes} processes and #{@worker_threads} threads per process..."

      @worker_processes.times do
        fork do
          start_worker_process(@socket)
        end
      end

      trap("INT") { shutdown! }
      Process.waitall
    end

    def shutdown!
      puts "[Server] Shutting down all workers..."

      # Ověříme, že existují workery k ukončení
      if @workers.is_a?(Array)
        @workers.each { |worker| worker.exit if worker.alive? }
      end

      Process.kill("TERM", 0) # Pošle SIGTERM všem forknutým workerům
      puts "[Server] Shutdown complete."
      exit(0)
    end


    private

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

    def start_thread_worker(queue, socket)
      Thread.new do
        loop do
          request, addr = queue.pop
          handle_request(request, addr, socket)
        end
      end
    end

    def handle_request(request, addr, socket)
      response = @middleware_stack.call(Takagi::Message::Inbound.new(request))

      unless response.is_a?(Takagi::Message::Outbound)
        response = Takagi::Message::Outbound.new(code: "5.00 Internal Server Error", payload: {})
      end

      socket.send(response.to_bytes, 0, addr[3], addr[1])
    rescue => e
      puts "[Error] handle_request failed: #{e.message}"
    end
  end
end
