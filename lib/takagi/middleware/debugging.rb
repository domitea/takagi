# frozen_string_literal: true

module Takagi
  module Middleware
    class Debugging
      def call(request)
        puts "[Debug] Request Details: #{request.inspect}"
        response = yield request
        puts "[Debug] Response Details: #{response.inspect}"
        response
      end
    end
  end
end
