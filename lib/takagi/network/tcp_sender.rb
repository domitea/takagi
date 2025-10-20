# frozen_string_literal: true

require 'socket'
require 'singleton'

module Takagi
  module Network
    class TcpSender
      include Singleton

      def transmit(packet, address, port)
        data = packet.is_a?(Takagi::Message::Outbound) ? packet.to_bytes : packet
        length = [data.bytesize].pack('n')
        socket = TCPSocket.new(address, port)
        socket.write(length + data)
        socket.close
      end
    end
  end
end
