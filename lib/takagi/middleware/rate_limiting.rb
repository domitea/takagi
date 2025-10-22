# frozen_string_literal: true

module Takagi
  module Middleware
    class RateLimiting
      def initialize
        @request_counts = Hash.new(0)
        @mutex = Mutex.new
      end

      def call(request)
        key = request.uri.path

        count = @mutex.synchronize do
          @request_counts[key] += 1
        end

        return request.to_response(code: 132, payload: { error: 'Too Many Requests' }) if count > 10

        yield request
      end
    end
  end
end
