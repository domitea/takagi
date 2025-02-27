# frozen_string_literal: true

module Takagi
  module Middleware
    class RateLimiting
      @@request_counts = Hash.new(0)

      def call(request)
        key = request.uri.path
        @@request_counts[key] += 1
        return request.to_response(code: 132, payload: { error: "Too Many Requests" }) if @@request_counts[key] > 10

        yield request
      end
    end
  end
end
