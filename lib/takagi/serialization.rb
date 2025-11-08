# frozen_string_literal: true

require_relative 'serialization/base'
require_relative 'serialization/registry'
require_relative 'serialization/json_serializer'
require_relative 'serialization/cbor_serializer'
require_relative 'serialization/text_serializer'
require_relative 'serialization/octet_stream_serializer'

module Takagi
  # Content-format serialization system
  #
  # Provides pluggable serialization/deserialization for CoAP content-formats.
  # Built-in serializers for common formats:
  # - JSON (application/json, code 50)
  # - CBOR (application/cbor, code 60)
  # - Text (text/plain, code 0)
  # - Binary (application/octet-stream, code 42)
  #
  # @example Encoding data
  #   Takagi::Serialization::Registry.encode({ temp: 25 }, 50)  # JSON
  #   Takagi::Serialization::Registry.encode({ temp: 25 }, 60)  # CBOR
  #
  # @example Decoding data
  #   Takagi::Serialization::Registry.decode(bytes, 50)  # JSON
  #   Takagi::Serialization::Registry.decode(bytes, 60)  # CBOR
  #
  # @example Registering custom serializer
  #   class XmlSerializer < Takagi::Serialization::Base
  #     def encode(data)
  #       # XML encoding logic
  #     end
  #
  #     def decode(bytes)
  #       # XML decoding logic
  #     end
  #
  #     def content_type
  #       'application/xml'
  #     end
  #
  #     def content_format_code
  #       41
  #     end
  #   end
  #
  #   Takagi::Serialization::Registry.register(41, XmlSerializer)
  #
  # @example Checking supported formats
  #   Takagi::Serialization::Registry.supports?(50)  # => true
  #   Takagi::Serialization::Registry.supported_formats  # => [0, 42, 50, 60]
  #   puts Takagi::Serialization::Registry.summary
  module Serialization
    # Auto-register built-in serializers on module load
    def self.register_defaults!
      Registry.register(
        CoAP::Registries::ContentFormat::TEXT_PLAIN,
        TextSerializer
      )

      Registry.register(
        CoAP::Registries::ContentFormat::OCTET_STREAM,
        OctetStreamSerializer
      )

      Registry.register(
        CoAP::Registries::ContentFormat::JSON,
        JsonSerializer
      )

      Registry.register(
        CoAP::Registries::ContentFormat::CBOR,
        CborSerializer
      )

      Takagi.logger.debug 'Registered default serializers: text/plain, octet-stream, JSON, CBOR'
    end

    # Convenience method: Encode data with format
    #
    # @param data [Object] Data to encode
    # @param format [Integer] Content-format code
    # @return [String] Encoded bytes
    #
    # @example
    #   Serialization.encode({ temp: 25 }, 50)  # JSON
    def self.encode(data, format)
      Registry.encode(data, format)
    end

    # Convenience method: Decode bytes with format
    #
    # @param bytes [String] Bytes to decode
    # @param format [Integer] Content-format code
    # @return [Object] Decoded data
    #
    # @example
    #   Serialization.decode(bytes, 50)  # JSON
    def self.decode(bytes, format)
      Registry.decode(bytes, format)
    end

    # Check if format is supported
    #
    # @param format [Integer] Content-format code
    # @return [Boolean]
    #
    # @example
    #   Serialization.supports?(50)  # => true
    def self.supports?(format)
      Registry.supports?(format)
    end
  end
end

# Auto-register defaults when module is loaded
Takagi::Serialization.register_defaults!
