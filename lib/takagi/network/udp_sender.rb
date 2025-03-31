# frozen_string_literal: true

module Takagi
  module Network
    class UdpSender
      include Singleton
      def setup(socket:)
        @socket = socket
      end

      def transmit(packet, address, port)
        data = packet.is_a?(Takagi::Message::Outbound) ? packet.to_bytes : packet
        @socket.send(data, 0, address, port)
      end
    end
  end
end
