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

      # DX Helpers for request inspection

      # Get CoAP option by number
      # @param option_number [Integer] The CoAP option number
      # @return [Object, nil] The option value
      def option(option_number)
        @options[option_number]
      end

      # Check if request has a specific CoAP option
      # @param option_number [Integer] The CoAP option number
      # @return [Boolean]
      def option?(option_number)
        @options.key?(option_number)
      end

      # Get Accept option (CoAP option 17)
      # @return [Integer, nil] The Accept content format
      def accept
        option(17)
      end

      # Check if request accepts a specific content format
      # @param format [String, Integer] Format name or number
      # @return [Boolean]
      def accept?(format)
        return false unless accept

        format_number = format.is_a?(Integer) ? format : content_format_to_number(format)
        accept == format_number
      end

      # Get Content-Format option (CoAP option 12)
      # @return [Integer, nil] The Content-Format
      def content_format
        option(12)
      end

      # Get query parameters as a hash
      # @return [Hash<String, String>]
      def query_params
        return {} unless @uri.query

        @uri.query.split('&').each_with_object({}) do |param, hash|
          key, value = param.split('=', 2)
          hash[key] = value || ''
        end
      end

      # Check if request is a GET
      # @return [Boolean]
      def get?
        method == 'GET'
      end

      # Check if request is a POST
      # @return [Boolean]
      def post?
        method == 'POST'
      end

      # Check if request is a PUT
      # @return [Boolean]
      def put?
        method == 'PUT'
      end

      # Check if request is a DELETE
      # @return [Boolean]
      def delete?
        method == 'DELETE'
      end

      # Check if request is an OBSERVE
      # @return [Boolean]
      def observe?
        method == 'OBSERVE'
      end

      private

      # Convert content format name to number
      def content_format_to_number(format)
        formats = {
          'text/plain' => 0,
          'application/link-format' => 40,
          'application/json' => 50,
          'application/cbor' => 60
        }
        formats[format.to_s.downcase] || 50
      end
    end
  end
end
