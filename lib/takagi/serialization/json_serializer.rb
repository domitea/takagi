# frozen_string_literal: true

require 'json'

module Takagi
  module Serialization
    # JSON serializer (RFC 8259)
    #
    # Handles application/json content-format (code 50).
    # Encodes Ruby objects to JSON and decodes JSON to Ruby objects.
    #
    # @example Encoding
    #   serializer = JsonSerializer.new
    #   bytes = serializer.encode({ temp: 25 })  # => "{\"temp\":25}"
    #
    # @example Decoding
    #   data = serializer.decode("{\"temp\":25}")  # => { "temp" => 25 }
    class JsonSerializer < Base
      # Encode Ruby object to JSON bytes
      #
      # @param data [Object] Ruby object to encode
      # @return [String] JSON string as binary
      # @raise [EncodeError] if encoding fails
      #
      # @example Hash encoding
      #   encode({ temp: 25 })  # => "{\"temp\":25}"
      #
      # @example Array encoding
      #   encode([1, 2, 3])  # => "[1,2,3]"
      #
      # @example String pass-through
      #   encode("hello")  # => "hello"
      def encode(data)
        return ''.b if data.nil? || data == ''

        result = case data
                 when String
                   # Already a string, assume it's valid
                   data
                 when Hash, Array
                   # Structured data - convert to JSON
                   JSON.generate(data)
                 else
                   # Other objects - try to_json
                   data.to_json
                 end

        result.b
      rescue StandardError => e
        raise EncodeError, "JSON encoding failed: #{e.message}"
      end

      # Decode JSON bytes to Ruby object
      #
      # @param bytes [String] JSON bytes to decode
      # @return [Object, nil] Decoded Ruby object (Hash, Array, String, etc.) or nil if invalid
      #
      # @example Object decoding
      #   decode("{\"temp\":25}")  # => { "temp" => 25 }
      #
      # @example Array decoding
      #   decode("[1,2,3]")  # => [1, 2, 3]
      #
      # @example Invalid JSON
      #   decode("{invalid}")  # => nil
      def decode(bytes)
        return nil if bytes.nil? || bytes.empty?

        JSON.parse(bytes)
      rescue JSON::ParserError => e
        nil  # Return nil for invalid JSON
      end

      # MIME type for JSON
      #
      # @return [String] 'application/json'
      def content_type
        'application/json'
      end

      # CoAP content-format code for JSON
      #
      # @return [Integer] 50 (RFC 7252 §12.3)
      def content_format_code
        CoAP::Registries::ContentFormat::JSON
      end

      # JSON is text-based, not binary
      #
      # @return [Boolean] false
      def binary?
        false
      end
    end
  end
end
