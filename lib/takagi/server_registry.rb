# frozen_string_literal: true

module Takagi
  # Registry for CoAP server implementations
  #
  # Allows registering different protocol implementations (UDP, TCP, DTLS, QUIC, etc.)
  # without modifying core code. Follows the Open/Closed Principle.
  #
  # @example Registering a server
  #   ServerRegistry.register(:udp, Server::Udp)
  #   ServerRegistry.register(:tcp, Server::Tcp)
  #
  # @example Building a server
  #   server = ServerRegistry.build(:tcp, port: 5683, worker_threads: 4)
  #
  # @example Adding a custom protocol
  #   class MyCustomServer
  #     def initialize(port:, **options)
  #       # ...
  #     end
  #   end
  #   ServerRegistry.register(:custom, MyCustomServer)
  class ServerRegistry
    class ProtocolNotFoundError < StandardError; end

    @servers = {}
    @mutex = Mutex.new

    class << self
      # Register a server implementation for a protocol
      #
      # @param protocol [Symbol] Protocol identifier (:udp, :tcp, :dtls, etc.)
      # @param klass [Class] Server class that responds to .new
      # @param options [Hash] Optional metadata (description, rfc, etc.)
      #
      # @example
      #   ServerRegistry.register(:udp, Server::Udp, rfc: 'RFC 7252')
      #   ServerRegistry.register(:tcp, Server::Tcp, rfc: 'RFC 8323')
      def register(protocol, klass, **options)
        @mutex.synchronize do
          @servers[protocol.to_sym] = {
            klass: klass,
            options: options
          }
        end
      end

      # Build a server instance for the given protocol
      #
      # @param protocol [Symbol] Protocol identifier
      # @param options [Hash] Options to pass to server constructor
      # @return [Object] Server instance
      # @raise [ProtocolNotFoundError] If protocol is not registered
      #
      # @example
      #   server = ServerRegistry.build(:tcp, port: 5683, worker_threads: 4)
      def build(protocol, **options)
        server_info = @servers[protocol.to_sym]
        raise ProtocolNotFoundError, "Unknown protocol: #{protocol}" unless server_info

        server_info[:klass].new(**options)
      end

      # Check if a protocol is registered
      #
      # @param protocol [Symbol] Protocol identifier
      # @return [Boolean] true if registered
      def registered?(protocol)
        @servers.key?(protocol.to_sym)
      end

      # Get all registered protocols
      #
      # @return [Array<Symbol>] List of protocol identifiers
      def protocols
        @servers.keys
      end

      # Get metadata for a protocol
      #
      # @param protocol [Symbol] Protocol identifier
      # @return [Hash, nil] Metadata hash or nil if not found
      def metadata_for(protocol)
        @servers[protocol.to_sym]&.dig(:options)
      end

      # Clear all registrations (useful for testing)
      def clear!
        @mutex.synchronize do
          @servers.clear
        end
      end
    end
  end
end
