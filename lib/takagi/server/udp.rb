# frozen_string_literal: true

require 'socket'
require_relative 'udp_worker'

module Takagi
  module Server
    # UDP server for handling CoAP messages
    class Udp
      def initialize(port: 5683, worker_processes: 2, worker_threads: 2,
                     middleware_stack: nil, router: nil, logger: nil, watcher: nil)
        @port = port
        @worker_processes = worker_processes
        @worker_threads = worker_threads
        @middleware_stack = middleware_stack || Takagi::MiddlewareStack.instance
        @router = router || Takagi::Router.instance
        @logger = logger || Takagi.logger
        @watcher = watcher || Takagi::Observer::Watcher.new(interval: 1)

        Initializer.run!

        @socket = UDPSocket.new
        @socket.bind('0.0.0.0', @port)
        Takagi::Network::UdpSender.instance.setup(socket: @socket)
        @sender = Takagi::Network::UdpSender.instance
      end

      # Starts the server with multiple worker processes
      def run!
        log_boot_details
        spawn_workers
        Takagi::ReactorRegistry.start_all
        @watcher.start
        trap('INT') { shutdown! }
        Process.waitall
      end

      # Gracefully shuts down all workers
      def shutdown!
        return if @shutdown_called

        @shutdown_called = true
        @watcher.stop
        close_socket
        terminate_workers
        Takagi::ReactorRegistry.stop_all
        exit(0) unless test_environment?
      end

      private

      def log_boot_details
        @logger.info "Starting Takagi server with #{@worker_processes} processes and #{@worker_threads} threads per process..."
        @logger.info "Takagi server has version #{Takagi::VERSION} with name '#{Takagi::NAME}'"
        @logger.debug "run #{@router.all_routes}"
      end

      def spawn_workers
        @worker_pids = Array.new(@worker_processes) do
          @logger.debug "process with #{@router.all_routes}"
          fork_worker
        end
      end

      def fork_worker
        fork do
          Process.setproctitle('takagi-worker')
          UdpWorker.new(**worker_configuration).run
        end
      end

      def worker_configuration
        {
          port: @port,
          socket: @socket,
          middleware_stack: @middleware_stack,
          sender: @sender,
          logger: @logger,
          threads: @worker_threads
        }
      end

      def close_socket
        return unless @socket && !@socket.closed?

        @socket.close
      rescue StandardError
        nil
      end

      def terminate_workers
        return unless @worker_pids.is_a?(Array)

        @worker_pids.each do |pid|
          Process.kill('TERM', pid)
        rescue Errno::ESRCH
          # worker already exited
        end
      end

      def test_environment?
        ENV['RACK_ENV'] == 'test' || defined?(RSpec)
      end
    end
  end
end
