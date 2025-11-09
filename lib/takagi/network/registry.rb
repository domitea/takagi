# frozen_string_literal: true

module Takagi
  module Network
    # Registry for transport implementations.
    # Provides discovery and factory methods for transports.
    class Registry
      class TransportNotFoundError < StandardError; end

      @transports = {}
      @mutex = Mutex.new

      class << self
        # Register a transport implementation
        #
        # @param name [Symbol] Transport identifier (:udp, :tcp, :dtls, etc.)
        # @param klass [Class] Transport class inheriting from Network::Base
        #
        # @example
        #   Registry.register(:udp, Network::Udp)
        #   Registry.register(:tcp, Network::Tcp)
        def register(name, klass)
          validate_transport!(klass)
          @mutex.synchronize do
            @transports[name.to_sym] = klass
          end
        end

        # Get a transport by name
        #
        # @param name [Symbol] Transport identifier
        # @return [Class] Transport class
        # @raise [TransportNotFoundError] If transport not registered
        def get(name)
          transport = @transports[name.to_sym]
          raise TransportNotFoundError, "Transport not found: #{name}" unless transport

          transport
        end

        # Find transport for a URI scheme
        #
        # @param scheme [String] URI scheme ('coap', 'coap+tcp', etc.)
        # @return [Class, nil] Transport class or nil if not found
        #
        # @example
        #   Registry.for_scheme('coap+tcp') # => Network::Tcp
        def for_scheme(scheme)
          @transports.values.find do |transport|
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

        # Get all registered transport names
        #
        # @return [Array<Symbol>] List of transport identifiers
        def all
          @transports.keys
        end

        # Check if a transport is registered
        #
        # @param name [Symbol] Transport identifier
        # @return [Boolean]
        def registered?(name)
          @transports.key?(name.to_sym)
        end

        # Clear all registrations (for testing)
        def clear!
          @mutex.synchronize do
            @transports.clear
          end
        end

        private

        def validate_transport!(klass)
          unless klass.respond_to?(:scheme) && klass.respond_to?(:default_port)
            raise ArgumentError, "#{klass} must implement .scheme and .default_port"
          end
        end
      end
    end
  end
end
