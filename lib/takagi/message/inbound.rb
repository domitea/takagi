# frozen_string_literal: true

module Takagi
  module Message
    # Class for inbound message that is coming to server
    class Inbound < Base
      attr_reader :method, :uri, :response_code

      def initialize(data)
        super
        @method = coap_code_to_method(@code)
        @response_code = coap_code_to_method(@code) if @code >= 65 # Response
        @uri = parse_coap_uri
        @logger.debug "CoAP Options: #{@options.inspect}"
        @logger.debug "Parsed CoAP URI: #{@uri}"
      end

      def to_response(code, payload, options: {})
        response_type = case @type
                        when 0 then 2  # CON → ACK
                        when 1 then 1  # NON → NON
                        else 3 # fallback → RST
                        end

        Outbound.new(code: code, payload: payload, token: @token, message_id: @message_id, type: response_type, options: options)
      end

      def parse_coap_uri
        options = @options || {}
        @logger.debug "Options received by parse_coap_uri: #{options.inspect}"

        host = options[3] || 'localhost'
        path_segments = Array(options[11]).flatten
        query_segments = Array(options[15]).flatten

        path = path_segments.empty? ? '/' : "/#{path_segments.join('/')}"
        query = query_segments.empty? ? nil : query_segments.join('&')
        URI::Generic.build(scheme: 'coap', host: host, path: path, query: query)
      end
    end
  end
end
