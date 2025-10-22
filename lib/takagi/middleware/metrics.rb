# frozen_string_literal: true

module Takagi
  module Middleware
    class Metrics
      attr_reader :metrics

      def initialize
        @metrics = Hash.new(0)
        @mutex = Mutex.new
      end

      def call(request)
        @mutex.synchronize { @metrics[:requests] += 1 }

        start_time = Time.now
        response = yield request

        @mutex.synchronize { @metrics[:latency] = Time.now - start_time }

        response
      end
    end
  end
end
