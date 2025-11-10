# frozen_string_literal: true

module Takagi
  module Network
    # Registry for transport implementations.
    #
    # Provides discovery and factory methods for transports.
    # Uses Registry::Base for thread-safe storage and consistent API.
    class Registry
      extend Takagi::Registry::Base

      # Error raised when transport is not found
      class TransportNotFoundError < Takagi::Registry::Base::NotFoundError; end

      class << self
        # Register a transport implementation
        #
        # @param name [Symbol] Transport identifier (:udp, :tcp, :dtls, etc.)
        # @param klass [Class] Transport class inheriting from Network::Base
        #
        # @example
        #   Registry.register(:udp, Network::Udp)
        #   Registry.register(:tcp, Network::Tcp)
        def register(name, klass, **metadata)
          super(name.to_sym, klass, **metadata)
        end

        # Find transport for a URI scheme
        #
        # @param scheme [String] URI scheme ('coap', 'coap+tcp', etc.)
        # @return [Class, nil] Transport class or nil if not found
        #
        # @example
        #   Registry.for_scheme('coap+tcp') # => Network::Tcp
        def for_scheme(scheme)
          # Get snapshot of transports to avoid holding lock during iteration
          snapshot = @mutex.synchronize { registry.values }

          snapshot.find do |transport|
            transport.scheme == scheme || transport.additional_schemes.include?(scheme)
          end
        end

        # Find transport for a URI
        #
        # @param uri [String, URI] URI to parse
        # @return [Class] Transport class
        # @raise [TransportNotFoundError] If no matching transport found
        #
        # @example
        #   Registry.for_uri('coap+tcp://localhost:5683') # => Network::Tcp
        def for_uri(uri)
          uri = URI(uri) if uri.is_a?(String)
          transport = for_scheme(uri.scheme)
          raise TransportNotFoundError, "No transport for scheme: #{uri.scheme}" unless transport

          transport
        end

        private

        # Validate transport implements required interface
        def validate_entry!(name, klass, **metadata)
          unless klass.respond_to?(:scheme) && klass.respond_to?(:default_port)
            raise Takagi::Registry::Base::ValidationError,
                  "#{klass} must implement .scheme and .default_port"
          end
        end
      end
    end
  end
end
