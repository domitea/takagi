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

        with_error_handling do
          log_generation
          packet = (build_header + token_bytes + build_payload_section).b
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

      def build_header
        version = 1
        type = @type || 2 # Default ACK
        token_length = @token.bytesize
        version_type_token_length = (version << 6) | (type << 4) | token_length
        [version_type_token_length, @code, @message_id].pack('CCn')
      end

      def token_bytes
        @token.to_s.b
      end

      def build_payload_section
        return ''.b if @payload.nil? || @payload.empty?

        "\xFF".b + @payload.b
      end

      def log_final_packet(packet)
        @logger.debug "Final CoAP packet: #{packet.inspect}"
      end
    end
  end
end
