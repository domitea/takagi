# frozen_string_literal: true

module Takagi
  module Serialization
    # Base interface for all content-format serializers
    #
    # Serializers implement encoding/decoding logic for specific content-formats.
    # Each serializer handles one CoAP content-format (MIME type).
    #
    # @example Implementing a custom serializer
    #   class XmlSerializer < Takagi::Serialization::Base
    #     def encode(data)
    #       # Convert Ruby object to XML bytes
    #     end
    #
    #     def decode(bytes)
    #       # Parse XML bytes to Ruby object
    #     end
    #
    #     def content_type
    #       'application/xml'
    #     end
    #
    #     def content_format_code
    #       41  # CoAP XML content-format
    #     end
    #   end
    #
    # @abstract Subclass and implement all methods
    class Base
      # Encode Ruby object to bytes
      #
      # @param data [Object] Ruby object to encode
      # @return [String] Binary string (ASCII-8BIT encoding)
      # @raise [EncodeError] if encoding fails
      #
      # @example
      #   serializer.encode({ temp: 25 })  # => "\x{...}"
      def encode(data)
        raise NotImplementedError, "#{self.class}#encode must be implemented"
      end

      # Decode bytes to Ruby object
      #
      # @param bytes [String] Binary string to decode
      # @return [Object] Decoded Ruby object
      # @raise [DecodeError] if decoding fails
      #
      # @example
      #   serializer.decode("\x{...}")  # => { temp: 25 }
      def decode(bytes)
        raise NotImplementedError, "#{self.class}#decode must be implemented"
      end

      # MIME type this serializer handles
      #
      # @return [String] MIME type (e.g., 'application/json')
      #
      # @example
      #   serializer.content_type  # => 'application/json'
      def content_type
        raise NotImplementedError, "#{self.class}#content_type must be implemented"
      end

      # CoAP content-format code
      #
      # @return [Integer] CoAP content-format code from RFC 7252 §12.3
      #
      # @example
      #   serializer.content_format_code  # => 50 (JSON)
      def content_format_code
        raise NotImplementedError, "#{self.class}#content_format_code must be implemented"
      end

      # Check if this serializer can handle binary data
      #
      # @return [Boolean] true if binary format
      def binary?
        false
      end

      # Human-readable name for this serializer
      #
      # @return [String] Serializer name
      def name
        self.class.name.split('::').last.sub(/Serializer$/, '')
      end
    end

    # Raised when encoding fails
    class EncodeError < StandardError; end

    # Raised when decoding fails
    class DecodeError < StandardError; end

    # Raised when content-format is not registered
    class UnknownFormatError < StandardError; end

    # Raised when serializer implementation is invalid
    class InvalidSerializerError < StandardError; end
  end
end
