# frozen_string_literal: true

module Takagi
  module Observer
    # Dispatches outbound notifications to subscribed observers.
    class Sender
      def initialize
        @sender = Takagi::Network::UdpSender.instance
      end

      def send_packet(subscriber, value)
        message = Takagi::Message::Outbound.new(
          code: '2.05',
          payload: value.to_s,
          token: subscriber[:token],
          message_id: rand(0..0xFFFF),
          type: 1 # NON
        )

        @sender.transmit(message, subscriber[:address], subscriber[:port])
      rescue StandardError => e
        Takagi.logger.error "Observer Notify Error: #{e.message}"
      end
    end
  end
end
