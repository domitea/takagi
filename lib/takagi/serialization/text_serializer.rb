# frozen_string_literal: true

module Takagi
  module Serialization
    # Text/plain serializer (RFC 2046)
    #
    # Handles text/plain content-format (code 0).
    # Simple UTF-8 text encoding/decoding.
    #
    # @example Encoding
    #   serializer = TextSerializer.new
    #   bytes = serializer.encode("Hello World")  # => "Hello World" (as UTF-8 bytes)
    #
    # @example Decoding
    #   text = serializer.decode(bytes)  # => "Hello World"
    class TextSerializer < Base
      # Encode object to UTF-8 text bytes
      #
      # @param data [Object] Object to encode (converted to string)
      # @return [String] UTF-8 encoded binary string
      # @raise [EncodeError] if encoding fails
      #
      # @example String encoding
      #   encode("hello")  # => "hello"
      #
      # @example Number encoding
      #   encode(42)  # => "42"
      #
      # @example Object encoding
      #   encode({ temp: 25 })  # => "{:temp=>25}"
      def encode(data)
        return ''.b if data.nil? || data == ''

        data.to_s.encode('UTF-8').b
      rescue Encoding::UndefinedConversionError => e
        raise EncodeError, "Text encoding failed (invalid UTF-8): #{e.message}"
      rescue StandardError => e
        raise EncodeError, "Text encoding failed: #{e.message}"
      end

      # Decode UTF-8 bytes to string
      #
      # @param bytes [String] UTF-8 binary data
      # @return [String] Decoded UTF-8 string
      # @raise [DecodeError] if decoding fails
      #
      # @example Text decoding
      #   decode(bytes)  # => "Hello World"
      def decode(bytes)
        return nil if bytes.nil? || bytes.empty?

        # Ensure UTF-8 encoding
        bytes.force_encoding('UTF-8')

        # Validate UTF-8
        unless bytes.valid_encoding?
          raise DecodeError, 'Invalid UTF-8 encoding'
        end

        bytes
      rescue StandardError => e
        raise DecodeError, "Text decoding failed: #{e.message}"
      end

      # MIME type for plain text
      #
      # @return [String] 'text/plain'
      def content_type
        'text/plain'
      end

      # CoAP content-format code for text/plain
      #
      # @return [Integer] 0 (RFC 7252 §12.3)
      def content_format_code
        CoAP::Registries::ContentFormat::TEXT_PLAIN
      end

      # Text is not binary
      #
      # @return [Boolean] false
      def binary?
        false
      end
    end
  end
end
