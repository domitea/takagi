# frozen_string_literal: true

module Takagi
  module Message
    class Outbound < Base
      def initialize(code, payload, token = nil, message_id = nil)
        @code = self.class.coap_method_to_code(code)
        @payload = payload.to_json.force_encoding("ASCII-8BIT")
        @token = token || "".b
        @message_id = message_id || rand(0..0xFFFF)
      end

      def to_bytes
        header = [0x60 | (@token.bytesize & 0x0F), @code, (@message_id >> 8) & 0xFF, @message_id & 0xFF].pack("C*")
        payload_marker = "\xFF".b
        header + @token + payload_marker + @payload
      end
    end
  end
end
