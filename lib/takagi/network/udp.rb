# frozen_string_literal: true

require_relative 'base'
require_relative 'framing/udp'

module Takagi
  module Network
    # UDP transport implementation (RFC 7252)
    class Udp < Base
      def self.scheme
        'coap'
      end

      def self.additional_schemes
        ['coaps'] # DTLS variant
      end

      def self.default_port
        5683
      end

      def self.rfc
        'RFC 7252'
      end

      def self.reliable?
        false
      end

      # Encode message for UDP transport (RFC 7252 format)
      def encode(message)
        Framing::Udp.encode(message)
      end

      # Decode UDP datagram into message
      def decode(data)
        Framing::Udp.decode(data)
      end

      # Create UDP sender
      def create_sender(options = {})
        require_relative 'udp_sender'
        UdpSender.instance
      end

      # Create UDP server
      def create_server(options = {})
        require_relative '../server/udp'
        Server::Udp.new(**options)
      end

      # Create UDP client (internal UdpClient class from client.rb)
      def create_client(options = {})
        # UdpClient is defined inside client.rb
        # We'll return the class reference for now
        # The actual instantiation happens in Client
        :udp_client
      end
    end
  end
end
