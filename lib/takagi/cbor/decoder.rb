# frozen_string_literal: true

module Takagi
  module CBOR
    # CBOR Decoder (RFC 8949)
    #
    # Decodes CBOR binary format to Ruby objects.
    # Optimized for IoT/CoAP workloads with minimal footprint.
    #
    # Supported types:
    # - Integers → Integer
    # - Floats → Float
    # - Text strings → String (UTF-8)
    # - Byte strings → String (binary)
    # - Arrays → Array
    # - Maps → Hash (string keys)
    # - Booleans → true/false
    # - null → nil
    # - Timestamps (tag 1) → Time
    #
    # @example Basic decoding
    #   Decoder.decode("\xA2ktempera...")
    #   # => { "temperature" => 25.5, "humidity" => 60 }
    #
    # Security features:
    # - Max nesting depth (prevents stack overflow)
    # - Max collection size (prevents memory exhaustion)
    class Decoder # rubocop:disable Metrics/ClassLength
      # CBOR Major Types (RFC 8949 §3)
      MAJOR_TYPE_UNSIGNED_INT = 0
      MAJOR_TYPE_NEGATIVE_INT = 1
      MAJOR_TYPE_BYTE_STRING = 2
      MAJOR_TYPE_TEXT_STRING = 3
      MAJOR_TYPE_ARRAY = 4
      MAJOR_TYPE_MAP = 5
      MAJOR_TYPE_TAG = 6
      MAJOR_TYPE_SIMPLE = 7

      # Simple values (RFC 8949 §3.3)
      SIMPLE_FALSE = 20
      SIMPLE_TRUE = 21
      SIMPLE_NULL = 22
      SIMPLE_FLOAT16 = 25
      SIMPLE_FLOAT32 = 26
      SIMPLE_FLOAT64 = 27

      # Security limits
      MAX_NESTING_DEPTH = 100
      MAX_COLLECTION_SIZE = 100_000

      # Tag values
      TAG_EPOCH_TIMESTAMP = 1

      MAJOR_TYPE_HANDLERS = {
        MAJOR_TYPE_UNSIGNED_INT => :handle_unsigned_int,
        MAJOR_TYPE_NEGATIVE_INT => :handle_negative_int,
        MAJOR_TYPE_BYTE_STRING => :read_bytes,
        MAJOR_TYPE_TEXT_STRING => :read_string,
        MAJOR_TYPE_ARRAY => :read_array,
        MAJOR_TYPE_MAP => :read_map,
        MAJOR_TYPE_TAG => :read_tagged,
        MAJOR_TYPE_SIMPLE => :read_simple
      }.freeze

      class << self
        # Decode CBOR bytes to Ruby object
        #
        # @param bytes [String] CBOR-encoded binary string
        # @return [Object] Decoded Ruby object
        # @raise [DecodeError] if bytes cannot be decoded
        #
        # @example
        #   Decoder.decode("\x18\x2A")         # => 42
        #   Decoder.decode("ehello")           # => "hello"
        #   Decoder.decode("\x83\x01\x02\x03") # => [1, 2, 3]
        def decode(bytes)
          new(bytes).decode
        end
      end

      # Initialize decoder with CBOR bytes
      #
      # @param bytes [String] CBOR-encoded binary string
      def initialize(bytes)
        @bytes = bytes.b
        @pos = 0
        @depth = 0
      end

      # Decode CBOR bytes to Ruby object
      #
      # @return [Object] Decoded Ruby object
      # @raise [DecodeError] if bytes cannot be decoded
      def decode
        check_depth!

        major_type, value = read_type_and_value
        handler = MAJOR_TYPE_HANDLERS[major_type]
        raise DecodeError, "Unknown major type: #{major_type}" unless handler

        send(handler, value)
      rescue DecodeError, UnsupportedError
        raise
      rescue StandardError => e
        raise DecodeError, "Decoding failed at position #{@pos}: #{e.message}"
      end

      private

      def handle_unsigned_int(value)
        value
      end

      def handle_negative_int(value)
        -1 - value
      end

      # Check nesting depth to prevent stack overflow
      def check_depth!
        return if @depth < MAX_NESTING_DEPTH

        raise DecodeError, "Maximum nesting depth exceeded (#{MAX_NESTING_DEPTH})"
      end

      # Read major type and additional value
      # RFC 8949 §3: Initial byte encoding
      #
      # Returns [major_type, value]
      # - major_type: 0-7 (3 bits)
      # - value: depends on additional info (5 bits)
      def read_type_and_value
        raise DecodeError, 'Unexpected end of input' if @pos >= @bytes.bytesize

        initial_byte = @bytes[@pos].ord
        @pos += 1

        major_type = initial_byte >> 5
        additional = initial_byte & 0x1F

        value = if major_type == MAJOR_TYPE_SIMPLE
                  additional
                else
                  decode_additional_info(additional)
                end

        [major_type, value]
      end

      # Decode additional information (RFC 8949 §3)
      #
      # Additional info encoding:
      # 0-23:   Value is directly in additional info
      # 24:     1-byte uint8 follows
      # 25:     2-byte uint16 follows
      # 26:     4-byte uint32 follows
      # 27:     8-byte uint64 follows
      # 28-30:  Reserved (error)
      # 31:     Indefinite length (not supported in minimal impl)
      def decode_additional_info(additional)
        case additional
        when 0..23
          # Value directly encoded
          additional
        when 24
          # 1-byte uint8 follows
          read_uint8
        when 25
          # 2-byte uint16 follows
          read_uint16
        when 26
          # 4-byte uint32 follows
          read_uint32
        when 27
          # 8-byte uint64 follows
          read_uint64
        when 28, 29, 30
          raise DecodeError, "Reserved additional info value: #{additional}"
        when 31
          raise UnsupportedError, 'Indefinite-length items not supported in minimal implementation'
        end
      end

      # Read unsigned 8-bit integer
      def read_uint8
        check_available(1)
        val = @bytes[@pos].ord
        @pos += 1
        val
      end

      # Read unsigned 16-bit integer (big-endian)
      def read_uint16
        check_available(2)
        val = @bytes[@pos, 2].unpack1('n')
        @pos += 2
        val
      end

      # Read unsigned 32-bit integer (big-endian)
      def read_uint32
        check_available(4)
        val = @bytes[@pos, 4].unpack1('N')
        @pos += 4
        val
      end

      # Read unsigned 64-bit integer (big-endian)
      def read_uint64
        check_available(8)
        val = @bytes[@pos, 8].unpack1('Q>')
        @pos += 8
        val
      end

      # Read byte string (binary data)
      def read_bytes(length)
        check_collection_size(length)
        check_available(length)

        bytes = @bytes[@pos, length]
        @pos += length
        bytes
      end

      # Read UTF-8 text string
      def read_string(length)
        check_collection_size(length)
        check_available(length)

        str = @bytes[@pos, length]
        @pos += length

        # Force UTF-8 encoding and validate
        str.force_encoding('UTF-8')

        raise DecodeError, 'Invalid UTF-8 encoding in text string' unless str.valid_encoding?

        str
      end

      # Read array
      def read_array(length)
        check_collection_size(length)

        @depth += 1

        arr = Array.new(length) { decode }

        @depth -= 1
        arr
      end

      # Read map (hash)
      def read_map(length)
        check_collection_size(length)

        @depth += 1

        hash = {}

        length.times do
          key = decode
          value = decode

          # Convert symbol keys to strings for consistency
          key = key.to_s if key.is_a?(Symbol)

          hash[key] = value
        end

        @depth -= 1
        hash
      end

      # Read tagged value (RFC 8949 §3.4)
      def read_tagged(tag)
        case tag
        when TAG_EPOCH_TIMESTAMP
          # Tag 1: Epoch-based timestamp
          timestamp_value = decode

          case timestamp_value
          when Integer, Float
            Time.at(timestamp_value)
          else
            raise DecodeError, "Invalid timestamp value type: #{timestamp_value.class}"
          end
        else
          # Unknown tag: decode value but ignore tag
          # This allows forward compatibility
          decode
        end
      end

      # Read simple value (RFC 8949 §3.3)
      def read_simple(value)
        case value
        when SIMPLE_FALSE
          false
        when SIMPLE_TRUE
          true
        when SIMPLE_NULL
          nil
        when SIMPLE_FLOAT16
          # 16-bit float (half-precision)
          read_float16
        when SIMPLE_FLOAT32
          # 32-bit float (single-precision)
          read_float32
        when SIMPLE_FLOAT64
          # 64-bit float (double-precision)
          read_float64
        when 0..19
          # Unassigned simple values (0-19)
          raise UnsupportedError, "Unassigned simple value: #{value}"
        when 24..31
          # Should not reach here (handled in decode_additional_info)
          raise DecodeError, "Invalid simple value: #{value}"
        else
          # Simple values 32-255 (extended)
          raise UnsupportedError, "Extended simple values not supported: #{value}"
        end
      end

      # Read 16-bit float (IEEE 754 half-precision)
      def read_float16
        check_available(2)

        # Read 16-bit big-endian
        half = @bytes[@pos, 2].unpack1('n')
        @pos += 2

        # Convert IEEE 754 half to Ruby float
        # Format: 1 sign bit, 5 exponent bits, 10 mantissa bits
        sign = (half >> 15) & 0x1
        exponent = (half >> 10) & 0x1F
        mantissa = half & 0x3FF

        if exponent.zero?
          # Subnormal or zero
          result = mantissa.to_f / (2**24)
        elsif exponent == 0x1F
          # Infinity or NaN
          return mantissa.zero? ? Float::INFINITY : Float::NAN
        else
          # Normalized
          result = (1.0 + (mantissa.to_f / (2**10))) * (2**(exponent - 15))
        end

        sign.zero? ? result : -result
      end

      # Read 32-bit float (IEEE 754 single-precision)
      def read_float32
        check_available(4)
        float_bytes = @bytes[@pos, 4]
        @pos += 4
        float_bytes.unpack1('g') # Big-endian single-precision float
      end

      # Read 64-bit float (IEEE 754 double-precision)
      def read_float64
        check_available(8)
        float_bytes = @bytes[@pos, 8]
        @pos += 8
        float_bytes.unpack1('G') # Big-endian double-precision float
      end

      # Check if enough bytes are available
      def check_available(needed)
        available = @bytes.bytesize - @pos
        return if available >= needed

        raise DecodeError, "Unexpected end of input (need #{needed} bytes, have #{available})"
      end

      # Check collection size to prevent memory exhaustion
      def check_collection_size(size)
        return if size <= MAX_COLLECTION_SIZE

        raise DecodeError, "Collection size #{size} exceeds maximum (#{MAX_COLLECTION_SIZE})"
      end
    end # rubocop:enable Metrics/ClassLength
  end
end
