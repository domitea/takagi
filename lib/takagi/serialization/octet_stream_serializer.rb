# frozen_string_literal: true

module Takagi
  module Serialization
    # Octet-stream serializer (RFC 2046)
    #
    # Handles application/octet-stream content-format (code 42).
    # Pass-through for raw binary data with no transformation.
    #
    # @example Encoding
    #   serializer = OctetStreamSerializer.new
    #   bytes = serializer.encode("\x00\x01\x02")  # => "\x00\x01\x02" (unchanged)
    #
    # @example Decoding
    #   data = serializer.decode(bytes)  # => raw bytes (unchanged)
    class OctetStreamSerializer < Base
      # Encode data to binary bytes
      #
      # Pass-through serializer - data is returned as-is in binary form.
      # Non-string objects are converted to string first.
      #
      # @param data [Object] Data to encode
      # @return [String] Binary string (ASCII-8BIT)
      # @raise [EncodeError] if encoding fails
      #
      # @example Binary data pass-through
      #   encode("\x00\x01\x02")  # => "\x00\x01\x02"
      #
      # @example String to binary
      #   encode("hello")  # => "hello" (as binary)
      def encode(data)
        return ''.b if data.nil? || data == ''

        # Convert to binary string
        result = data.is_a?(String) ? data : data.to_s
        result.b
      rescue StandardError => e
        raise EncodeError, "Octet-stream encoding failed: #{e.message}"
      end

      # Decode binary bytes
      #
      # Pass-through decoder - bytes are returned as-is.
      #
      # @param bytes [String] Binary data
      # @return [String] Binary string (ASCII-8BIT)
      # @raise [DecodeError] if decoding fails
      #
      # @example Binary data pass-through
      #   decode(bytes)  # => bytes (unchanged)
      def decode(bytes)
        return nil if bytes.nil? || bytes.empty?

        # Return as binary string
        bytes.b
      rescue StandardError => e
        raise DecodeError, "Octet-stream decoding failed: #{e.message}"
      end

      # MIME type for octet-stream
      #
      # @return [String] 'application/octet-stream'
      def content_type
        'application/octet-stream'
      end

      # CoAP content-format code for octet-stream
      #
      # @return [Integer] 42 (RFC 7252 §12.3)
      def content_format_code
        CoAP::Registries::ContentFormat::OCTET_STREAM
      end

      # Octet-stream is binary
      #
      # @return [Boolean] true
      def binary?
        true
      end
    end
  end
end
