# frozen_string_literal: true

module Takagi
  module Middleware
    class Debugging
      # Logs request details before passing it to the next middleware
      # @param request [Takagi::Message::Inbound] Incoming CoAP request
      def call(request)
        puts "[Debug] Request Details: #{request.inspect}"
        response = yield request
        puts "[Debug] Response Details: #{response.inspect}"
        response
      end
    end
  end
end
