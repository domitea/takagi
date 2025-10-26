# frozen_string_literal: true

module Takagi
  module CoAP
    module Registries
      # CoAP Content-Format Registry (RFC 7252 §12.3)
      #
      # Extensible registry for CoAP content-format codes.
      # Plugins can register custom content formats without modifying core code.
      #
      # @example Using predefined formats
      #   Takagi::CoAP::Registries::ContentFormat::JSON          # => 50
      #   Takagi::CoAP::Registries::ContentFormat::TEXT_PLAIN    # => 0
      #
      # @example Registering a custom format
      #   Takagi::CoAP::Registries::ContentFormat.register(65000, 'application/custom', :custom)
      #   Takagi::CoAP::Registries::ContentFormat::CUSTOM  # => 65000
      #
      # @example Looking up format names
      #   Takagi::CoAP::Registries::ContentFormat.name_for(50)  # => "application/json"
      class ContentFormat < Base
        # RFC 7252 §12.3 - Content-Format Registry
        register(0, 'text/plain', :text_plain, rfc: 'RFC 7252 §12.3')
        register(40, 'application/link-format', :link_format, rfc: 'RFC 6690')
        register(41, 'application/xml', :xml, rfc: 'RFC 7252 §12.3')
        register(42, 'application/octet-stream', :octet_stream, rfc: 'RFC 7252 §12.3')
        register(47, 'application/exi', :exi, rfc: 'RFC 7252 §12.3')
        register(50, 'application/json', :json, rfc: 'RFC 7252 §12.3')
        register(60, 'application/cbor', :cbor, rfc: 'RFC 7049')

        # Get MIME type for a content-format code
        # @param code [Integer] Content-format code
        # @return [String, nil] MIME type
        def self.mime_type_for(code)
          name_for(code)
        end

        # Get content-format code for a MIME type
        # @param mime_type [String] MIME type
        # @return [Integer, nil] Content-format code
        def self.code_for_mime(mime_type)
          value_for(mime_type)
        end

        # Check if format is JSON-based
        # @param code [Integer] Content-format code
        # @return [Boolean] true if JSON format
        def self.json?(code)
          mime = mime_type_for(code)
          mime&.include?('json') || false
        end

        # Check if format is CBOR-based
        # @param code [Integer] Content-format code
        # @return [Boolean] true if CBOR format
        def self.cbor?(code)
          mime = mime_type_for(code)
          mime&.include?('cbor') || false
        end

        # Check if format is text-based
        # @param code [Integer] Content-format code
        # @return [Boolean] true if text format
        def self.text?(code)
          mime = mime_type_for(code)
          mime&.start_with?('text/') || false
        end
      end
    end
  end
end
