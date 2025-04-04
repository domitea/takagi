# frozen_string_literal: true

module Takagi
  module Message
    # Class for request message that is coming from server to another server through observable

    class Request < Base
      METHOD_CODES = {
        get: 1,
        post: 2,
        put: 3,
        delete: 4
      }.freeze

      def initialize(method:, uri:, token: nil, observe: nil, message_id: nil)
        super()
        @method = method
        @uri = uri
        @token = token || SecureRandom.hex(4)
        @observe = observe
        @message_id = message_id || rand(0..0xFFFF)
      end

      def to_bytes
        version = 1
        type = 0 # Confirmable
        token_length = @token.bytesize
        code = METHOD_CODES[@method] || 0
        ver_type_token = ((version << 6) | (type << 4) | token_length)
        header = [ver_type_token, code, @message_id].pack('CCn')

        options = encode_options
        token_part = @token.b
        packet = (header + token_part + options).b

        Takagi.logger.debug "Generated Request packet: #{packet.inspect}"
        packet
      end

      private

      def encode_options
        last_option_number = 0
        encoded = []

        # Observe musí jít jako PRVNÍ, aby delta vyšla správně
        unless @observe.nil?
          encoded << encode_option(6, [@observe].pack('C'), last_option_number)
          last_option_number = 6
        end

        @uri.path.split('/').reject(&:empty?).each do |segment|
          encoded << encode_option(11, segment, last_option_number)
          last_option_number = 11
        end

        encoded.join.b
      end

      def encode_option(option_number, value, last_option_number)
        delta = option_number - last_option_number
        length = value.bytesize

        delta_encoded, delta_extra = encode_extended(delta)
        length_encoded, length_extra = encode_extended(length)

        option_header = [(delta_encoded << 4) | length_encoded].pack('C')
        option_header + delta_extra + length_extra + value.b
      end

      def encode_extended(val)
        case val
        when 0..12
          [val, '']
        when 13..268
          [13, [val - 13].pack('C')]
        when 269..65804
          [14, [val - 269].pack('n')]
        else
          raise "Unsupported option delta/length: #{val}"
        end
      end
    end
  end
end
