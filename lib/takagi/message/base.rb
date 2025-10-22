# frozen_string_literal: true

module Takagi
  module Message
    COAP_CODES = {
      0 => 'EMPTY',
      1 => 'GET',
      2 => 'POST',
      3 => 'PUT',
      4 => 'DELETE',
      65 => '2.01 Created',
      66 => '2.02 Deleted',
      67 => '2.03 Valid',
      68 => '2.04 Changed',
      69 => '2.05 Content',
      128 => '4.00 Bad Request',
      129 => '4.01 Unauthorized',
      130 => '4.02 Bad Option',
      131 => '4.03 Forbidden',
      132 => '4.04 Not Found',
      133 => '4.05 Method Not Allowed',
      140 => '4.12 Precondition Failed',
      141 => '4.13 Request Entity Too Large',
      143 => '4.15 Unsupported Content Format',
      160 => '5.00 Internal Server Error',
      161 => '5.01 Not Implemented',
      162 => '5.02 Bad Gateway',
      163 => '5.03 Service Unavailable'
    }.freeze

    COAP_CODES_NUMBERS = {
      '2.05' => 69,  # Content
      '4.04' => 132, # Not Found
      '5.00' => 160  # Internal Server Error
    }.freeze

    # Base class for message
    class Base
      attr_reader :version, :type, :token, :message_id, :payload, :options, :code

      def initialize(data = nil)
        parse(data) if data.is_a?(String) || data.is_a?(IO)
        @data = data
        @logger = Takagi.logger
      end

      def coap_code_to_method(code)
        if code == 1 && @options && @options[6]
          'OBSERVE'
        else
          COAP_CODES[code] || 'UNKNOWN'
        end
      end

      def coap_method_to_code(method)
        COAP_CODES.key(method) || 0
      end

      private

      def parse(data)
        bytes = data.bytes
        @version = (bytes[0] >> 6) & 0b11
        @type    = (bytes[0] >> 4) & 0b11
        token_length = bytes[0] & 0b1111
        @code = bytes[1]
        @message_id = bytes[2..3].pack('C*').unpack1('n')
        @token   = token_length.positive? ? bytes[4, token_length].pack('C*') : ''.b
        @options = parse_options(bytes[(4 + token_length)..])
        @payload = extract_payload(data)
      end

      def parse_options(bytes)
        options = {}
        position = 0
        last_option_number = 0

        while position < bytes.length && bytes[position] != 0xFF
          byte = bytes[position]
          position += 1

          delta_raw = (byte >> 4) & 0x0F
          length_raw = byte & 0x0F

          delta, position = decode_extended_value(bytes, position, delta_raw)
          length, position = decode_extended_value(bytes, position, length_raw)

          option_number = last_option_number + delta
          value = bytes[position, length].pack('C*')
          position += length

          store_option(options, option_number, value)

          last_option_number = option_number
        end

        Takagi.logger.debug "Parsed CoAP options: #{options.inspect}"
        options
      end

      def extract_payload(data)
        Takagi.logger.debug "Extracting payload: #{data.inspect}"
        payload_start = data.index("\xFF".b)
        return nil unless payload_start

        payload = data[(payload_start + 1)..].dup.force_encoding('ASCII-8BIT')
        utf8 = payload.dup.force_encoding('UTF-8')
        utf8.valid_encoding? ? utf8 : payload
      end

      def decode_extended_value(bytes, position, raw_value)
        case raw_value
        when 13
          [bytes[position] + 13, position + 1]
        when 14
          extended = bytes[position, 2].pack('C*').unpack1('n') + 269
          [extended, position + 2]
        else
          [raw_value, position]
        end
      end

      def store_option(options, option_number, value)
        formatted = coerce_option_value(value)

        case option_number
        when 11, 15
          options[option_number] ||= []
          options[option_number] << formatted
        else
          if options.key?(option_number)
            options[option_number] = Array(options[option_number]) << formatted
          else
            options[option_number] = formatted
          end
        end
      end

      def coerce_option_value(value)
        ascii = value.dup.force_encoding('ASCII-8BIT')
        return ascii.force_encoding('UTF-8') if ascii.valid_encoding?

        ascii
      end
    end
  end
end
