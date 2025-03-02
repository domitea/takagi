# frozen_string_literal: true

module Takagi
  module Message
    class Base
      attr_reader :version, :type, :token, :message_id, :payload, :options, :code

      COAP_CODES = {
        0 => "Empty",
        1 => "GET",
        2 => "POST",
        3 => "PUT",
        4 => "DELETE",
        65 => "2.01 Created",
        66 => "2.02 Deleted",
        67 => "2.03 Valid",
        68 => "2.04 Changed",
        69 => "2.05 Content",
        128 => "4.00 Bad Request",
        129 => "4.01 Unauthorized",
        130 => "4.02 Bad Option",
        131 => "4.03 Forbidden",
        132 => "4.04 Not Found",
        133 => "4.05 Method Not Allowed",
        140 => "4.12 Precondition Failed",
        141 => "4.13 Request Entity Too Large",
        143 => "4.15 Unsupported Content Format",
        160 => "5.00 Internal Server Error",
        161 => "5.01 Not Implemented",
        162 => "5.02 Bad Gateway",
        163 => "5.03 Service Unavailable"
      }.freeze

      COAP_CODES_NUMBERS = {
        "2.05" => 69,  # Content
        "4.04" => 132, # Not Found
        "5.00" => 160  # Internal Server Error
      }

      def initialize(data = nil)
        parse(data) if data
        @data = data
      end

      def coap_code_to_method(code)
        COAP_CODES[code] || "UNKNOWN"
      end

      def coap_method_to_code(method)
        COAP_CODES.key(method) || 0
      end

      private

      def parse(data)
        @version = (data.bytes[0] >> 6) & 0b11
        @type = (data.bytes[0] >> 4) & 0b11
        token_length = data.bytes[0] & 0b1111
        @code = data.bytes[1]
        @message_id = data.bytes[2..3].pack("C*").unpack1("n")
        @token = token_length.positive? ? data.bytes[4, token_length].pack("C*") : "".b
        @options = parse_options(data.bytes[(4 + token_length)..])
        @payload = extract_payload(data)
      end

      def parse_options(bytes)
        Thread.current[:options] = {}

        options_start = 0
        last_option = 0

        while options_start < bytes.length && bytes[options_start] != 255 # 0xFF = start of payload
          delta = (bytes[options_start] >> 4) & 0x0F  # Číslo opce
          len = bytes[options_start] & 0x0F           # Délka dat
          options_start += 1

          option_number = last_option + delta
          option_value = bytes[options_start, len].pack("C*").b

          if option_number == 11
            Thread.current[:options][11] ||= []
            Thread.current[:options][11] << option_value.force_encoding("UTF-8")
          else
            Thread.current[:options][option_number] = option_value.force_encoding("UTF-8")
          end

          options_start += len
          last_option = option_number
        end

        puts "[Debug] Parsed CoAP options: #{Thread.current[:options].inspect}"
      end

      def extract_payload(data)
        payload_start = data.index("\xFF".b)
        return nil unless payload_start

        payload = data[(payload_start + 1)..].force_encoding("ASCII-8BIT")
        payload.valid_encoding? ? payload.force_encoding("UTF-8") : payload
      end
    end
  end
end
