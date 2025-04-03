# frozen_string_literal: true

module Takagi
  module Observer
    class Client
      def initialize(uri)
        @uri = URI.parse(uri)
        @token = SecureRandom.hex(4)
        @socket = UDPSocket.new
        @on_notify = nil
      end

      def on_notify(&block)
        @on_notify = block
      end

      def subscribe
        send_observe_request
        listen_for_notifications
      end

      private

      def send_observe_request
        message = Takagi::Message::Request.new(
          method: :get,
          uri: @uri,
          token: @token,
          observe: 0
        )
        @socket.send(message.to_bytes, 0, @uri.host, @uri.port || 5683)
      end

      def listen_for_notifications
        Thread.new do
          loop do
            data, _addr = @socket.recvfrom(1024)
            inbound = Takagi::Message::Inbound.new(data)
            next unless inbound.token == @token

            payload = inbound.payload
            Takagi.logger.info "Received notify: #{payload}"
            @on_notify&.call(payload, inbound)
          end
        end
      end
    end
  end
end