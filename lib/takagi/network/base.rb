# frozen_string_literal: true

module Takagi
  module Network
    # Base class for all transport implementations.
    # Each transport encapsulates protocol-specific framing, I/O, and metadata.
    class Base
      class << self
        # URI scheme for this transport (e.g., 'coap', 'coap+tcp')
        # @return [String]
        def scheme
          raise NotImplementedError, "#{self} must implement .scheme"
        end

        # Default port for this transport
        # @return [Integer]
        def default_port
          raise NotImplementedError, "#{self} must implement .default_port"
        end

        # RFC reference for this transport
        # @return [String]
        def rfc
          raise NotImplementedError, "#{self} must implement .rfc"
        end

        # Is this a reliable transport?
        # @return [Boolean]
        def reliable?
          raise NotImplementedError, "#{self} must implement .reliable?"
        end

        # Additional schemes this transport supports (e.g., ['coaps'] for secure variant)
        # @return [Array<String>]
        def additional_schemes
          []
        end
      end

      # Encode a CoAP message for this transport
      # @param message [Message::Outbound] Message to encode
      # @return [String] Binary data ready for transmission
      def encode(message)
        raise NotImplementedError, "#{self.class} must implement #encode"
      end

      # Decode binary data into a CoAP message
      # @param data [String] Binary data from the wire
      # @return [Message::Inbound] Parsed message
      def decode(data)
        raise NotImplementedError, "#{self.class} must implement #decode"
      end

      # Create a sender for this transport
      # @param options [Hash] Transport-specific options
      # @return [Object] Sender instance
      def create_sender(options = {})
        raise NotImplementedError, "#{self.class} must implement #create_sender"
      end

      # Create a server for this transport
      # @param options [Hash] Server options
      # @return [Object] Server instance
      def create_server(options = {})
        raise NotImplementedError, "#{self.class} must implement #create_server"
      end

      # Create a client for this transport
      # @param options [Hash] Client options
      # @return [Object] Client instance
      def create_client(options = {})
        raise NotImplementedError, "#{self.class} must implement #create_client"
      end
    end
  end
end
