# frozen_string_literal: true

require 'singleton'

module Takagi
  module Network
    # Sends UDP responses over the shared socket configured at boot.
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
