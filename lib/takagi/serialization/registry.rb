# frozen_string_literal: true

module Takagi
  module Serialization
    # Registry for content-format serializers
    #
    # Manages serializer instances and provides encoding/decoding dispatch.
    # Thread-safe singleton registry using Registry::Base.
    #
    # @example Register a custom serializer
    #   Takagi::Serialization::Registry.register(41, XmlSerializer)
    #
    # @example Encode data
    #   bytes = Takagi::Serialization::Registry.encode({ temp: 25 }, 50)  # JSON
    #
    # @example Decode data
    #   data = Takagi::Serialization::Registry.decode(bytes, 50)  # JSON
    class Registry
      extend Takagi::Registry::Base

      class << self
        # Register a serializer for a content-format code
        #
        # @param code [Integer] CoAP content-format code (RFC 7252 §12.3)
        # @param serializer [Base, Class] Serializer instance or class
        # @return [void]
        # @raise [ValidationError] if serializer doesn't implement Base interface
        #
        # @example Register with class
        #   Registry.register(50, JsonSerializer)
        #
        # @example Register with instance
        #   Registry.register(50, JsonSerializer.new)
        def register(code, serializer, **metadata)
          instance = instantiate_serializer(serializer)
          super(code, instance, **metadata)
        end

        # Get serializer for content-format code
        #
        # @param code [Integer] CoAP content-format code
        # @return [Base, nil] Serializer instance or nil if not registered
        #
        # @example
        #   serializer = Registry.serializer_for(50)  # => JsonSerializer instance
        def serializer_for(code)
          self[code]
        end
        alias for serializer_for # Alias for convenience (but use carefully as 'for' is a keyword)

        # Encode data using appropriate serializer
        #
        # @param data [Object] Ruby object to encode
        # @param code [Integer] CoAP content-format code
        # @return [String] Encoded binary string
        # @raise [UnknownFormatError] if format not registered
        # @raise [EncodeError] if encoding fails
        #
        # @example
        #   bytes = Registry.encode({ temp: 25 }, 50)  # JSON encoding
        def encode(data, code)
          serializer = serializer_for(code)
          raise UnknownFormatError, "No serializer for content-format #{code}" unless serializer

          serializer.encode(data)
        rescue UnknownFormatError, EncodeError
          raise
        rescue StandardError => e
          raise EncodeError, "Encoding failed for format #{code}: #{e.message}"
        end

        # Decode bytes using appropriate serializer
        #
        # @param bytes [String] Binary data to decode
        # @param code [Integer] CoAP content-format code
        # @return [Object] Decoded Ruby object
        # @raise [UnknownFormatError] if format not registered
        # @raise [DecodeError] if decoding fails
        #
        # @example
        #   data = Registry.decode(bytes, 50)  # JSON decoding
        def decode(bytes, code)
          serializer = serializer_for(code)
          raise UnknownFormatError, "No serializer for content-format #{code}" unless serializer

          serializer.decode(bytes)
        rescue UnknownFormatError, DecodeError
          raise
        rescue StandardError => e
          raise DecodeError, "Decoding failed for format #{code}: #{e.message}"
        end

        # Check if format is supported
        #
        # @param code [Integer] CoAP content-format code
        # @return [Boolean] true if serializer registered for this code
        #
        # @example
        #   Registry.supports?(50)  # => true (JSON)
        #   Registry.supports?(999) # => false
        def supports?(code)
          registered?(code)
        end

        # Get list of supported content-format codes
        #
        # @return [Array<Integer>] List of registered codes
        #
        # @example
        #   Registry.supported_formats  # => [0, 40, 50, 60]
        def supported_formats
          keys.sort
        end

        # Get human-readable summary of registered formats
        #
        # @return [String] Summary text
        #
        # @example
        #   puts Registry.summary
        #   # => "Registered Serializers:
        #   #      50: application/json (Json)
        #   #      60: application/cbor (Cbor)"
        def summary
          lines = ["Registered Serializers:"]
          # Get snapshot to avoid holding lock during iteration
          snapshot = @mutex.synchronize { registry.dup }
          snapshot.sort.each do |code, serializer|
            lines << "  #{code}: #{serializer.content_type} (#{serializer.name})"
          end
          lines.join("\n")
        end

        private

        # Instantiate serializer from class or return instance
        def instantiate_serializer(serializer)
          if serializer.is_a?(Class)
            serializer.new
          else
            serializer
          end
        end

        # Hook called by Registry::Base to validate entries before registration
        def validate_entry!(code, serializer, **metadata)
          unless serializer.is_a?(Base)
            raise Takagi::Registry::Base::ValidationError,
                  "Serializer must inherit from Takagi::Serialization::Base"
          end

          # Test that required methods are implemented
          required_methods = %i[encode decode content_type content_format_code]
          required_methods.each do |method|
            begin
              serializer.public_send(method, *dummy_args_for(method))
            rescue NotImplementedError => e
              raise Takagi::Registry::Base::ValidationError,
                    "Serializer missing implementation: #{e.message}"
            rescue ArgumentError
              # Method exists but has wrong arity - that's OK, we'll catch it at runtime
            end
          end
        rescue Takagi::Registry::Base::ValidationError
          raise
        rescue StandardError => e
          # Ignore other errors during validation - we're just checking if methods exist
          nil
        end

        # Hook called after successful registration
        def after_register(code, serializer, **metadata)
          Takagi.logger.debug "Registered serializer for content-format #{code}: #{serializer.content_type}"
        end

        # Get dummy arguments for method testing
        def dummy_args_for(method)
          case method
          when :encode then [nil]
          when :decode then ['']
          else []
          end
        end
      end
    end
  end
end
