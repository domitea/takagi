# frozen_string_literal: true

module Takagi
  module Message
    # Base class for message
    class Base
      attr_reader :version, :type, :token, :message_id, :payload, :options, :code

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
        Thread.current[:options] = {}
        pos = 0
        last_option_number = 0

        while pos < bytes.length && bytes[pos] != 0xFF
          byte = bytes[pos]
          pos += 1

          delta_raw = (byte >> 4) & 0x0F
          len_raw   = byte & 0x0F

          delta = case delta_raw
                  when 13 then bytes[pos] + 13.tap { pos += 1 }
                  when 14 then bytes[pos, 2].pack('C*').unpack1('n') + 269.tap { pos += 2 }
                  else delta_raw
                  end

          length = case len_raw
                   when 13 then bytes[pos] + 13.tap { pos += 1 }
                   when 14 then bytes[pos, 2].pack('C*').unpack1('n') + 269.tap { pos += 2 }
                   else len_raw
                   end

          option_number = last_option_number + delta
          value = bytes[pos, length].pack('C*')
          pos += length

          if option_number == 11
            Thread.current[:options][11] ||= []
            Thread.current[:options][11] << value.force_encoding('UTF-8')
          else
            Thread.current[:options][option_number] = value.force_encoding('UTF-8')
          end

          last_option_number = option_number
        end

        Takagi.logger.debug "Parsed CoAP options: #{Thread.current[:options].inspect}"
        Thread.current[:options]
      end

      def extract_payload(data)
        Takagi.logger.debug "Extracting payload: #{data.inspect}"
        payload_start = data.index("\xFF".b)
        return nil unless payload_start

        payload = data[(payload_start + 1)..].force_encoding('ASCII-8BIT')
        payload.valid_encoding? ? payload.force_encoding('UTF-8') : payload
      end
    end
  end
end
