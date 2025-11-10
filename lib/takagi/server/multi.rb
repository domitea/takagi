# frozen_string_literal: true

module Takagi
  module Server
    # Helper class to run multiple servers concurrently
    class Multi
      def initialize(servers)
        @servers = servers
        @threads = []
      end

      def run!
        # Set flag instead of calling shutdown! directly from trap context
        # This avoids "can't be called from trap context" errors with logger
        trap('INT') { @shutdown_requested = true }

        @threads = @servers.map { |srv| Thread.new { srv.run! } }

        # Monitor threads and check for shutdown signal
        until @threads.all? { |t| !t.alive? } || @shutdown_requested
          sleep 0.1
        end

        # Call shutdown if it was requested by signal
        shutdown! if @shutdown_requested

        @threads.each(&:join)
      end

      def shutdown!
        @servers.each(&:shutdown!)
        @threads.each(&:join)

        # Join the server thread if it was spawned via spawn!
        if defined?(@server_thread) && @server_thread&.alive?
          @server_thread.join(5) # Wait up to 5 seconds
        end
      end
    end
  end
end
