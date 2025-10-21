# frozen_string_literal: true

module Takagi
  # Tracks background reactor instances and controls their lifecycle.
  module ReactorRegistry
    @reactors = []

    class << self
      attr_reader :reactors

      def register(reactor)
        @reactors << reactor
      end

      def start_all
        @reactors.each(&:start)
      end

      def stop_all
        @reactors.each do |reactor|
          reactor.stop if reactor.respond_to?(:stop)
        end
      end
    end
  end
end
