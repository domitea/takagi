# frozen_string_literal: true

module Takagi
  module Message
    class Inbound < Base
      attr_reader :method, :uri, :response_code

      def initialize(data)
        super
        @method = coap_code_to_method(@code)
        @response_code = coap_code_to_method(@code) if @code >= 65 # Response
        @uri = parse_coap_uri
        puts "[Debug] CoAP Options: #{Thread.current[:options].inspect}"
        puts "[Debug] Parsed CoAP URI: #{@uri}"
      end

      def to_response(code, payload)
        Outbound.new(code: code, payload: payload, token: @token, message_id: @message_id)
      end

      def parse_coap_uri
        options = Thread.current[:options] || {} # Získáme thread-safe verzi options
        puts "[Debug] Options received by parse_coap_uri: #{options.inspect}"

        host = options[3] || "localhost"
        path_segments = Array(options[11]).flatten

        path = path_segments.empty? ? "/" : "/" + path_segments.join("/")
        URI::Generic.build(scheme: "coap", host: host, path: path)
      end
    end
  end
end
