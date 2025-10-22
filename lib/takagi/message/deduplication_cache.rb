# frozen_string_literal: true

module Takagi
  module Message
    # Implements message deduplication as per RFC 7252 Section 4.4
    #
    # The server MUST detect duplicates by matching both Message ID and source endpoint.
    # When a duplicate CON message is received, the server MUST resend the cached response.
    #
    # Cache entries expire after EXCHANGE_LIFETIME (247 seconds per RFC 7252 §4.8.2)
    class DeduplicationCache
      # RFC 7252 §4.8.2: EXCHANGE_LIFETIME = 247 seconds
      EXCHANGE_LIFETIME = 247

      # Entry contains the cached response and metadata
      CacheEntry = Struct.new(:response_data, :timestamp, :source_key) do
        def expired?(current_time)
          current_time - timestamp > EXCHANGE_LIFETIME
        end
      end

      def initialize
        @cache = {}
        @mutex = Mutex.new
      end

      # Check if message is a duplicate and return cached response if available
      # @param message_id [Integer] The CoAP Message ID
      # @param source_endpoint [String] Source IP:Port identifier
      # @return [String, nil] Cached response data or nil if not a duplicate
      def check_duplicate(message_id, source_endpoint)
        @mutex.synchronize do
          cleanup_expired_entries
          key = cache_key(message_id, source_endpoint)
          entry = @cache[key]
          entry&.response_data
        end
      end

      # Store a response for future duplicate detection
      # @param message_id [Integer] The CoAP Message ID
      # @param source_endpoint [String] Source IP:Port identifier
      # @param response_data [String] The serialized response to cache
      def store_response(message_id, source_endpoint, response_data)
        @mutex.synchronize do
          key = cache_key(message_id, source_endpoint)
          @cache[key] = CacheEntry.new(
            response_data,
            Time.now.to_f,
            source_endpoint
          )
        end
      end

      # Clear all cache entries (useful for testing)
      def clear
        @mutex.synchronize { @cache.clear }
      end

      # Get cache statistics
      def stats
        @mutex.synchronize do
          {
            size: @cache.size,
            entries: @cache.keys
          }
        end
      end

      private

      def cache_key(message_id, source_endpoint)
        "#{source_endpoint}:#{message_id}"
      end

      # Remove expired entries to prevent unbounded memory growth
      # RFC 7252 §4.8.2: entries older than EXCHANGE_LIFETIME should be discarded
      def cleanup_expired_entries
        current_time = Time.now.to_f
        @cache.delete_if { |_key, entry| entry.expired?(current_time) }
      end
    end
  end
end
