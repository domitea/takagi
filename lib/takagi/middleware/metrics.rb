# frozen_string_literal: true

module Takagi
  module Middleware
    class Metrics
      @@metrics = Hash.new(0)

      def call(request)
        @@metrics[:requests] += 1
        start_time = Time.now
        response = yield request
        @@metrics[:latency] = Time.now - start_time
        response
      end
    end
  end
end
