# frozen_string_literal: true

module Takagi
  class EventBus
    # Background thread for stale observer cleanup
    #
    # Periodically cleans up stale observers from the ObserveRegistry.
    # Observers are considered stale if they haven't received notifications
    # for longer than max_age seconds.
    #
    # @example
    #   cleanup = ObserverCleanup.new(interval: 60, max_age: 600)
    #   cleanup.start
    #   # ... cleanup runs in background ...
    #   cleanup.stop
    class ObserverCleanup
      attr_reader :interval, :max_age

      # Initialize observer cleanup
      # @param interval [Integer] Cleanup interval in seconds (default: 60)
      # @param max_age [Integer] Max observer age in seconds (default: 600)
      def initialize(interval: 60, max_age: 600)
        @interval = interval
        @max_age = max_age
        @running = false
        @thread = nil
        @mutex = Mutex.new
        @stats = { runs: 0, cleaned: 0, errors: 0 }
      end

      # Start the cleanup thread
      def start
        @mutex.synchronize do
          return if @running

          @running = true
          @thread = Thread.new { run_cleanup_loop }
          @thread.name = 'ObserverCleanup'
        end

        Takagi.logger.info "Observer cleanup started (interval: #{@interval}s, max_age: #{@max_age}s)"
      end

      # Stop the cleanup thread
      def stop
        @mutex.synchronize do
          return unless @running

          @running = false
          @thread&.kill
          @thread&.join(5) # Wait up to 5 seconds
          @thread = nil
        end

        Takagi.logger.info 'Observer cleanup stopped'
      end

      # Check if cleanup is running
      # @return [Boolean]
      def running?
        @mutex.synchronize { @running }
      end

      # Get cleanup statistics
      # @return [Hash] Statistics
      def stats
        @mutex.synchronize { @stats.dup }
      end

      # Force a cleanup run (for testing)
      def cleanup_now
        cleanup_stale_observers
      end

      private

      # Main cleanup loop
      def run_cleanup_loop
        while @running
          begin
            sleep @interval
            cleanup_stale_observers if @running
          rescue StandardError => e
            @mutex.synchronize { @stats[:errors] += 1 }
            Takagi.logger.error "Observer cleanup error: #{e.class} - #{e.message}"
          end
        end
      end

      # Cleanup stale observers from ObserveRegistry
      def cleanup_stale_observers
        @mutex.synchronize { @stats[:runs] += 1 }

        cleaned_count = 0

        # TODO: Implement actual cleanup logic
        # Current ObserveRegistry doesn't track observer timestamps
        # Options:
        # 1. Add :created_at and :last_notified_at to subscription structure
        # 2. Track observer activity in a separate data structure
        # 3. Use heartbeat mechanism to detect stale observers
        #
        # For now, log that cleanup ran successfully
        Takagi.logger.debug "Observer cleanup completed (run ##{@stats[:runs]})"

        # Example implementation (when timestamps are added):
        # if defined?(Takagi::ObserveRegistry)
        #   now = Time.now
        #
        #   Takagi::ObserveRegistry.subscriptions.each do |path, subscribers|
        #     subscribers.reject! do |sub|
        #       # Remove if no handler (remote observer) and hasn't been active
        #       if !sub[:handler] && sub[:last_notified_at]
        #         stale = (now - sub[:last_notified_at]) > @max_age
        #         cleaned_count += 1 if stale
        #         stale
        #       else
        #         false
        #       end
        #     end
        #   end
        # end

        @mutex.synchronize { @stats[:cleaned] += cleaned_count }

        Takagi.logger.info "Cleaned up #{cleaned_count} stale observers" if cleaned_count.positive?

        cleaned_count
      end
    end
  end
end
