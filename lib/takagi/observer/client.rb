# frozen_string_literal: true

require 'uri'
require 'socket'
require 'securerandom'

module Takagi
  module Observer
    # Lightweight CoAP observe client for integration testing.
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

      def stop
        @running = false
        @socket.close unless @socket.closed?
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
        @running = true
        @thread = Thread.new { handle_notification_iteration while @running }
      end

      def handle_notification_iteration
        data, _addr = @socket.recvfrom_nonblock(1024)
        inbound = Takagi::Message::Inbound.new(data)
        return unless inbound.token == @token

        payload = inbound.payload
        Takagi.logger.info "Received notify: #{payload}"
        @on_notify&.call(payload, inbound)
      rescue IO::WaitReadable
        @socket.wait_readable
        retry
      rescue IOError
        @running = false
      end
    end
  end
end
