# frozen_string_literal: true

module Takagi
  module Middleware
    class Caching
      @@cache = {}

      def call(request)
        return @@cache[request.uri.path] if @@cache.key?(request.uri.path)

        response = yield request
        @@cache[request.uri.path] = response
        response
      end
    end
  end
end
