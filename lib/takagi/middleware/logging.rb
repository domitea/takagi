# frozen_string_literal: true

module Takagi
  module Middleware
    class Logging
      def call(request)
        Takagi.logger.info "Received request: #{request.uri.path}"
        response = yield request
        Takagi.logger.info "Response code: #{response.code}, Payload: #{response.payload}"
        response
      end
    end
  end
end
