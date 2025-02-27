# frozen_string_literal: true

module Takagi
  module Middleware
    class Logging
      def call(request)
        puts "[Middleware] Received request: #{request.uri.path}"
        response = yield request
        puts "[Middleware] Response code: #{response.code}, Payload: #{response.payload}"
        response
      end
    end
  end
end
