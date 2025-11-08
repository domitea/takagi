# frozen_string_literal: true

module Takagi
  module Serialization
    # CBOR serializer (RFC 8949)
    #
    # Handles application/cbor content-format (code 60).
    # Encodes Ruby objects to CBOR binary format and decodes CBOR to Ruby objects.
    #
    # Uses Takagi's built-in CBOR implementation for zero external dependencies.
    #
    # @example Encoding
    #   serializer = CborSerializer.new
    #   bytes = serializer.encode({ temp: 25 })  # => "\xA1dtemp\x18\x19"
    #
    # @example Decoding
    #   data = serializer.decode("\xA1dtemp\x18\x19")  # => { "temp" => 25 }
    class CborSerializer < Base
      # Encode Ruby object to CBOR bytes
      #
      # @param data [Object] Ruby object to encode
      # @return [String] CBOR binary string
      # @raise [EncodeError] if encoding fails
      #
      # @example Hash encoding
      #   encode({ temp: 25 })  # => CBOR bytes
      #
      # @example Array encoding
      #   encode([1, 2, 3])  # => CBOR bytes
      #
      # @example Supported types
      #   - Integer (signed/unsigned, up to 64-bit)
      #   - Float (64-bit IEEE 754)
      #   - String (UTF-8)
      #   - Array
      #   - Hash
      #   - true, false, nil
      #   - Time (as timestamp)
      def encode(data)
        return ''.b if data.nil? || data == ''

        CBOR::Encoder.encode(data)
      rescue CBOR::EncodeError => e
        raise EncodeError, "CBOR encoding failed: #{e.message}"
      rescue StandardError => e
        raise EncodeError, "CBOR encoding error: #{e.message}"
      end

      # Decode CBOR bytes to Ruby object
      #
      # @param bytes [String] CBOR binary data
      # @return [Object] Decoded Ruby object (Hash, Array, Integer, etc.)
      # @raise [DecodeError] if decoding fails
      #
      # @example Object decoding
      #   decode(cbor_bytes)  # => { "temp" => 25 }
      #
      # @example Array decoding
      #   decode(cbor_bytes)  # => [1, 2, 3]
      def decode(bytes)
        return nil if bytes.nil? || bytes.empty?

        CBOR::Decoder.decode(bytes)
      rescue CBOR::DecodeError => e
        raise DecodeError, "CBOR decoding failed: #{e.message}"
      rescue StandardError => e
        raise DecodeError, "CBOR decoding error: #{e.message}"
      end

      # MIME type for CBOR
      #
      # @return [String] 'application/cbor'
      def content_type
        'application/cbor'
      end

      # CoAP content-format code for CBOR
      #
      # @return [Integer] 60 (RFC 7049)
      def content_format_code
        CoAP::Registries::ContentFormat::CBOR
      end

      # CBOR is a binary format
      #
      # @return [Boolean] true
      def binary?
        true
      end
    end
  end
end
