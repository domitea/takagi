# frozen_string_literal: true

module Takagi
  module Middleware
    class Caching
      def initialize
        @cache = {}
        @mutex = Mutex.new
      end

      def call(request)
        cached_response = @mutex.synchronize { @cache[request.uri.path] }
        return cached_response if cached_response

        response = yield request

        @mutex.synchronize { @cache[request.uri.path] = response }

        response
      end
    end
  end
end
