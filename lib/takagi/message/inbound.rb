# frozen_string_literal: true

module Takagi
  module Message
    class Inbound < Base
      attr_reader :method, :uri, :response_code

      def initialize(data)
        super
        @method = coap_code_to_method(@code)
        @response_code = coap_code_to_method(@code) if @code >= 65 # Response
        @uri = parse_uri(@options)
      end

      def to_response(code, payload)
        Outbound.new(code, payload, @token, @message_id)
      end

      private

      def parse_uri(options)
        path_segments = options[11] ? options[11].split("/") : []
        path = "/#{path_segments.join("/")}"
        URI::Generic.build(path: path)
      end
    end
  end
end
