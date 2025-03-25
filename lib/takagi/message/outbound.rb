# frozen_string_literal: true

module Takagi
  module Message
    # Class for outbound message that is coming from server
    class Outbound < Base
      def initialize(code:, payload:, token: nil, message_id: nil, type: 1)
        super
        @code = coap_method_to_code(code)
        @token = token || ''.b
        @message_id = message_id || rand(0..0xFFFF)
        @type = type

        @payload = if payload.nil?
                     nil
                   elsif payload.is_a?(String)
                     payload.b
                   else
                     payload.to_json.b
                   end
      end

      def to_bytes
        return ''.b unless @code

        begin
          puts "[Debug] Generating CoAP packet for code #{@code}, payload #{@payload.inspect}, \
            message_id #{@message_id}, token #{@token.inspect}, type #{@type}"

          version = 1
          type = @type || 2 # Default ACK
          token_length = @token.bytesize
          version_type_token_length = ((version << 6) | (type << 4) | token_length)
          header = [version_type_token_length, @code, @message_id].pack('CCn')

          token_payload = @token.to_s.b
          payload_part = if @payload.nil? || @payload.empty?
                           ''.b
                         else
                           "\xFF".b + @payload.b
                         end

          packet = (header + token_payload + payload_part).b

          puts "[Debug] Final CoAP packet: #{packet.inspect}"

          packet
        rescue StandardError => e
          puts "[Error] to_bytes failed: #{e.message} at #{e.backtrace.first}"
          ''.b
        end
      end
    end
  end
end
