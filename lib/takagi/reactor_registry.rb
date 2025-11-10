# frozen_string_literal: true

module Takagi
  # Tracks background reactor instances and controls their lifecycle.
  #
  # Uses Registry::Base for thread-safe storage and consistent API.
  # Reactors are stored with auto-incrementing IDs.
  #
  # NOTE: Cannot be moved to Reactor::Registry because Reactor is already a class.
  # Keeping as ReactorRegistry at top level for now.
  #
  # @example Register and manage reactors
  #   reactor = SomeReactor.new
  #   id = ReactorRegistry.register(reactor)
  #   ReactorRegistry.start_all
  #   ReactorRegistry.stop_all
  module ReactorRegistry
    extend Registry::Base

    class << self
      # Register a reactor instance
      #
      # @param reactor [Object] Reactor instance
      # @return [Integer] Auto-assigned reactor ID
      def register(reactor)
        id = next_id
        super(id, reactor)
        id
      end

      # Get all registered reactors
      #
      # @return [Array] List of reactor instances
      def reactors
        @mutex.synchronize { registry.values }
      end

      # Start all registered reactors
      #
      # @return [void]
      def start_all
        reactors.each(&:start)
      end

      # Stop all registered reactors
      #
      # @return [void]
      def stop_all
        reactors.each do |reactor|
          reactor.stop if reactor.respond_to?(:stop)
        end
      end

      private

      def next_id
        @mutex.synchronize do
          @next_id ||= 0
          @next_id += 1
        end
      end
    end
  end
end
