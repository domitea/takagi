# frozen_string_literal: true

module Takagi
  module Message
    # Class for inbound message that is coming to server
    class Inbound < Base
      attr_reader :method, :uri, :response_code

      def initialize(data, transport: :udp)
        super(data, transport: transport)
        @method = coap_code_to_method(@code)
        @response_code = coap_code_to_method(@code) if @code >= CoAP::Response::CREATED # Response
        @uri = parse_coap_uri
        @logger.debug "CoAP Options: #{@options.inspect}"
        @logger.debug "Parsed CoAP URI: #{@uri}"
      end

      def to_response(code, payload, options: {})
        # For TCP transport, type is not used (RFC 8323)
        response_type = if @transport == :tcp
                          0  # No type field in TCP CoAP
                        else
                          case @type
                          when CoAP::MessageType::CON then CoAP::MessageType::ACK  # CON → ACK
                          when CoAP::MessageType::NON then CoAP::MessageType::NON  # NON → NON
                          else CoAP::MessageType::RST # fallback → RST
                          end
                        end

        Outbound.new(
          code: code,
          payload: payload,
          token: @token,
          message_id: @message_id,
          type: response_type,
          options: options,
          transport: @transport
        )
      end

      def parse_coap_uri
        options = @options || {}
        @logger.debug "Options received by parse_coap_uri: #{options.inspect}"

        host = options[CoAP::Option::URI_HOST] || 'localhost'
        path_segments = Array(options[CoAP::Option::URI_PATH]).flatten
        query_segments = Array(options[CoAP::Option::URI_QUERY]).flatten

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

      # Get Accept option
      # @return [Integer, nil] The Accept content format
      def accept
        option(CoAP::Option::ACCEPT)
      end

      # Check if request accepts a specific content format
      # @param format [String, Integer] Format name or number
      # @return [Boolean]
      def accept?(format)
        return false unless accept

        format_number = format.is_a?(Integer) ? format : content_format_to_number(format)
        accept == format_number
      end

      # Get Content-Format option
      # @return [Integer, nil] The Content-Format
      def content_format
        option(CoAP::Option::CONTENT_FORMAT)
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

      # Convert content format name to number using CoAP registry
      def content_format_to_number(format)
        formats = {
          'text/plain' => CoAP::ContentFormat::TEXT_PLAIN,
          'application/link-format' => CoAP::ContentFormat::LINK_FORMAT,
          'application/json' => CoAP::ContentFormat::JSON,
          'application/cbor' => CoAP::ContentFormat::CBOR
        }
        formats[format.to_s.downcase] || CoAP::ContentFormat::JSON
      end
    end
  end
end
