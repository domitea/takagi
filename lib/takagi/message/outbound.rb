# frozen_string_literal: true

module Takagi
  module Message
    # Class for outbound message that is coming from server
    class Outbound < Base
      def initialize(code:, payload:, token: nil, message_id: nil, type: CoAP::MessageType::NON, options: {}, transport: :udp)
        super(nil, transport: transport)  # Call Base.initialize with transport
        @code = coap_method_to_code(code)
        @token = token || ''.b
        @message_id = message_id || rand(0..0xFFFF)
        @type = type
        @options = normalize_options(options)

        @payload = if payload.nil?
                     nil
                   elsif payload.is_a?(String)
                     payload.b
                   else
                     payload.to_json.b
                   end
      end

      def to_bytes(transport: nil)
        return ''.b unless @code

        # Use provided transport or fall back to instance variable
        actual_transport = transport || @transport

        with_error_handling do
          log_generation
          packet = case actual_transport
                   when :tcp
                     build_tcp_message
                   else
                     build_udp_message
                   end
          log_final_packet(packet)
          packet
        end
      end

      private

      def with_error_handling
        yield
      rescue StandardError => e
        @logger.error "To_bytes failed: #{e.message} at #{e.backtrace.first}"
        ''.b
      end

      def log_generation
        @logger.debug "Generating CoAP packet for code #{@code}, payload #{@payload.inspect}, " \
                      "message_id #{@message_id}, token #{@token.inspect}, type #{@type}"
      end

      # Build UDP CoAP message (RFC 7252)
      def build_udp_message
        (build_header + token_bytes + build_options_section + build_payload_section).b
      end

      # Build TCP CoAP message (RFC 8323 §3.2)
      # Format: Len+TKL (1 byte) | Code (1 byte) | Token (TKL bytes) | Options | Payload
      # Note: The Len nibble is calculated by the caller (encode_tcp_frame)
      def build_tcp_message
        token_length = @token.bytesize
        # For TCP, we only set TKL in lower nibble; length nibble will be set during framing
        first_byte = (0 << 4) | token_length  # Length nibble = 0 (placeholder)
        packet = [first_byte, @code].pack('CC')
        packet += token_bytes
        packet += build_options_section
        packet += build_payload_section
        packet.b
      end

      def build_header
        version = Takagi::CoAP::VERSION
        type = @type || CoAP::MessageType::ACK # Default ACK
        token_length = @token.bytesize
        version_type_token_length = (version << 6) | (type << 4) | token_length
        [version_type_token_length, @code, @message_id].pack('CCn')
      end

      def token_bytes
        @token.to_s.b
      end

      def build_options_section
        return ''.b if @options.empty?

        encoded = ''.b
        last_option_number = 0

        flattened_options.each do |number, value|
          value_bytes = encode_option_value(value)
          delta = number - last_option_number

          delta_nibble, delta_extension = encode_option_header_value(delta)
          length_nibble, length_extension = encode_option_header_value(value_bytes.bytesize)

          option_byte = (delta_nibble << 4) | length_nibble
          encoded << option_byte.chr
          encoded << delta_extension if delta_extension
          encoded << length_extension if length_extension
          encoded << value_bytes

          last_option_number = number
        end

        encoded
      end

      def build_payload_section
        return ''.b if @payload.nil? || @payload.empty?

        "\xFF".b + @payload.b
      end

      def log_final_packet(packet)
        @logger.debug "Final CoAP packet: #{packet.inspect}"
      end

      def normalize_options(options)
        return {} unless options.is_a?(Hash)

        @logger.debug "Packet options are: #{options.inspect}"

        options.each_with_object({}) do |(key, value), acc|
          numeric_key = Integer(key)
          values = Array(value)
          acc[numeric_key] = values
        end
      rescue ArgumentError
        {}
      end

      def flattened_options
        @options.flat_map do |number, values|
          values.map { |value| [number, value] }
        end.sort_by.with_index { |(number, _), index| [number, index] }
      end

      def encode_option_value(value)
        # Special handling for TCP signaling "empty" options
        if @transport == :tcp && value.is_a?(Integer) && value.zero?
          return "".b  # ← empty option (len=0)
        end

        case value
        when Integer
          encode_integer_option_value(value)
        else
          value.to_s.b
        end
      end

      def encode_integer_option_value(value)
        return [value].pack('C') if value <= 0xFF
        return [value].pack('n') if value <= 0xFFFF

        [value].pack('N')
      end

      def encode_option_header_value(value)
        case value
        when 0..12
          [value, nil]
        when 13..268
          [13, [value - 13].pack('C')]
        when 269..65_804
          [14, [value - 269].pack('n')]
        else
          raise ArgumentError, 'Option value too large'
        end
      end
    end
  end
end
