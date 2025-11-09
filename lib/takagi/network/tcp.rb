# frozen_string_literal: true

require_relative 'base'
require_relative 'framing/tcp'

module Takagi
  module Network
    # TCP transport implementation (RFC 8323)
    class Tcp < Base
      def self.scheme
        'coap+tcp'
      end

      def self.additional_schemes
        ['coaps+tcp'] # TLS variant
      end

      def self.default_port
        5683
      end

      def self.rfc
        'RFC 8323'
      end

      def self.reliable?
        true
      end

      # Encode message for TCP transport (RFC 8323 format)
      def encode(message)
        Framing::Tcp.encode(message)
      end

      # Decode TCP stream data into message
      def decode(data)
        Framing::Tcp.decode(data)
      end

      # Create TCP sender (currently uses existing TcpSender singleton)
      # TODO: Replace with connection pool in Phase 5
      def create_sender(options = {})
        require_relative 'tcp_sender'
        TcpSender.instance
      end

      # Create TCP server
      def create_server(options = {})
        require_relative '../server/tcp'
        Server::Tcp.new(**options)
      end

      # Create TCP client
      def create_client(options = {})
        # TcpClient is a separate class
        :tcp_client
      end
    end
  end
end
