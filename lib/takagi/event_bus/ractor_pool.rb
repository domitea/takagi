# frozen_string_literal: true

module Takagi
  class EventBus
    # Fixed-size Ractor pool for async event delivery (pure Ruby)
    # Zero runtime dependencies - uses native Ractors from Ruby 3.0+
    #
    # Note: Uses Thread pool instead of Ractor pool due to Ractor's
    # shareable object restrictions. Will use Ractors in future when
    # limitations are resolved.
    #
    # @example
    #   pool = RactorPool.new(10)
    #   pool.post { puts "Hello from worker!" }
    #   pool.shutdown
    class RactorPool
      attr_reader :size

      # Initialize the pool
      # @param size [Integer] Number of workers in the pool (default: 10)
      def initialize(size = 10)
        @size = size
        @work_queue = Queue.new
        @workers = []
        @mutex = Mutex.new
        @shutdown = false
        initialize_pool
      end

      # Post work to the pool
      # @yield Block to execute in a worker
      # @raise [RuntimeError] If pool is shutdown
      def post(&block)
        raise 'Pool is shutdown' if @shutdown

        @work_queue.push(block)
      end

      # Shutdown the pool gracefully
      # Waits for all workers to finish their current work
      def shutdown
        @mutex.synchronize do
          return if @shutdown

          @shutdown = true

          # Send termination signals
          @size.times { @work_queue.push(nil) }

          # Wait for all workers to complete
          @workers.each(&:join)
          @workers.clear
        end
      end

      # Check if pool is running
      # @return [Boolean]
      def running?
        !@shutdown
      end

      private

      # Initialize worker threads
      # TODO: Use Ractors when shareable object limitations are resolved
      def initialize_pool
        @size.times do |i|
          @workers << Thread.new do
            Thread.current.name = "EventBus-#{i}"

            loop do
              work = @work_queue.pop
              break if work.nil? # Termination signal

              begin
                work.call
              rescue StandardError => e
                # Log error but keep thread alive
                warn "Worker #{Thread.current.name} error: #{e.class} - #{e.message}"
              end
            end
          end
        end
      end
    end
  end
end
