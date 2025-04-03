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
        # Uri-Path options
        options = @uri.path.split('/').reject(&:empty?).map do |segment|
          encode_option(11, segment) # Uri-Path = 11
        end
        # Observe option
        if @observe
          options << encode_option(6, [@observe].pack('C')) # Observe = 6
        end
        options.join.b
      end

      def encode_option(number, value)
        delta = number
        length = value.bytesize
        [(delta << 4) | length, value].pack('CA*')
      end
    end
  end
end
