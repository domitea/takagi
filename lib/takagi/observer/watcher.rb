# frozen_string_literal: true

module Takagi
  module Observer
    # Periodically notifies observers by re-running registered handlers.
    class Watcher
      def initialize(interval: 1)
        @interval = interval
        @running = false
        @thread = nil
      end

      def start
        return @thread if @running

        @running = true
        @thread = Thread.new do
          while @running
            Takagi::ObserveRegistry.subscriptions.each_key do |path|
              observable_route = Takagi::Base.router.find_observable(path)
              next unless observable_route

              handler = observable_route.block
              current_value = handler.call(nil)

              Takagi::ObserveRegistry.notify(path, current_value)
            end
            sleep @interval
          end
          @thread
        rescue StandardError => e
          Takagi.logger.error "Observer Watcher Error: #{e.message}"
        end
      end

      def stop
        @running = false
        @thread&.join
      end
    end
  end
end
