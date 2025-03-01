# frozen_string_literal: true

module Takagi
  module Message
    class Inbound < Base
      attr_reader :method, :uri, :response_code

      def initialize(data)
        super
        @method = coap_code_to_method(@code)
        @response_code = coap_code_to_method(@code) if @code >= 65 # Response
        @uri = URI.parse("coap://#{@options[3]}/#{@options[11]}")
      end

      def to_response(code, payload)
        Outbound.new(code, payload, @token, @message_id)
      end
    end
  end
end
