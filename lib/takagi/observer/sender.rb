# frozen_string_literal: true

module Takagi
  module Observer
    # Dispatches outbound notifications to subscribed observers.
    # Supports multiple transports (UDP, TCP, etc.) via transport registry.
    class Sender
      def initialize(transport: :udp)
        @transport = transport
        # NEW: Use transport registry to get appropriate sender
        transport_class = Takagi::Network::Registry.get(@transport)
        transport_impl = transport_class.new
        @sender = transport_impl.create_sender
      rescue Takagi::Network::Registry::TransportNotFoundError
        # Fallback to UDP if transport not found
        Takagi.logger.warn "Transport #{@transport} not found, using UDP"
        @sender = Takagi::Network::UdpSender.instance
      end

      def send_packet(subscriber, value)
        # Get transport from subscriber metadata, or use instance default
        transport = subscriber[:transport] || @transport

        message = Takagi::Message::Outbound.new(
          code: '2.05',
          payload: value.to_s,
          token: subscriber[:token],
          message_id: rand(0..0xFFFF),
          type: 1, # NON
          transport: transport
        )

        @sender.transmit(message, subscriber[:address], subscriber[:port])
      rescue StandardError => e
        Takagi.logger.error "Observer Notify Error: #{e.message}"
      end
    end
  end
end
