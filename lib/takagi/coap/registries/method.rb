# frozen_string_literal: true

module Takagi
  module CoAP
    module Registries
      # CoAP Method Code Registry (RFC 7252 §12.1.1)
      #
      # Extensible registry for CoAP request method codes.
      # Plugins can register custom methods without modifying core code.
      #
      # @example Using predefined methods
      #   Takagi::CoAP::Registries::Method::GET    # => 1
      #   Takagi::CoAP::Registries::Method::POST   # => 2
      #
      # @example Registering a custom method
      #   Takagi::CoAP::Registries::Method.register(5, 'FETCH', :fetch, rfc: 'RFC 8132')
      #   Takagi::CoAP::Registries::Method::FETCH  # => 5
      #
      # @example Looking up method names
      #   Takagi::CoAP::Registries::Method.name_for(1)  # => "GET"
      class Method < Base
        # RFC 7252 §5.8 - Method Codes
        register(0, 'EMPTY', :empty, rfc: 'RFC 7252 §5.8')
        register(1, 'GET', :get, rfc: 'RFC 7252 §5.8.1')
        register(2, 'POST', :post, rfc: 'RFC 7252 §5.8.2')
        register(3, 'PUT', :put, rfc: 'RFC 7252 §5.8.3')
        register(4, 'DELETE', :delete, rfc: 'RFC 7252 §5.8.4')

        # Check if code is a valid method code
        # @param code [Integer] Code to check
        # @return [Boolean] true if valid method
        def self.valid?(code)
          (0..31).include?(code) && registered?(code)
        end
      end
    end
  end
end
