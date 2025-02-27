# frozen_string_literal: true

module Takagi
  module Middleware
    class Authentication
      def call(request)
        return request.to_response(code: 129, payload: { error: "Unauthorized" }) unless valid_token?(request)

        yield request
      end

      private

      def valid_token?(request)
        request.token && request.token == "valid-token"
      end
    end
  end
end
