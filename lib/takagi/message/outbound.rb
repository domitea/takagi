# frozen_string_literal: true

module Takagi
  module Message
    class Outbound < Base
      def initialize(code:, payload:, token: nil, message_id: nil)
        @code = coap_method_to_code(code)
        @payload = payload.to_json.force_encoding("ASCII-8BIT")
        @token = token || "".b
        @message_id = message_id || rand(0..0xFFFF)
      end

      def to_bytes
        return "".b unless @code && @payload # Nikdy nesmí vrátit nil!

        begin
          puts "[Debug] Generating CoAP packet for code #{@code}, payload #{@payload.inspect}, message_id #{@message_id}, token #{@token.inspect}"

          version_type_token_length = 0x60 # Verze 1 (bity 0110), Typ zprávy: Confirmable (00)
          header = [version_type_token_length, @code, @message_id, @token.bytesize].pack("CCnC")

          token_payload = @token.to_s.b

          # Přidáme `\xFF` (oddělovač payloadu) pouze pokud payload není prázdný
          payload_part = @payload.to_s.empty? ? "".b : "\xFF".b + @payload.to_s.b

          # Finální paket
          packet = (header + token_payload + payload_part).b

          puts "[Debug] Final CoAP packet: #{packet.inspect}"

          packet
        rescue StandardError => e
          puts "[Error] to_bytes failed: #{e.message} at #{e.backtrace.first}"
          "".b # Fail-safe: pokud něco selže, vrátíme prázdný string
        end
      end

    end
  end
end
