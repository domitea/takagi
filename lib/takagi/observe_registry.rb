# frozen_string_literal: true

module Takagi
  # Keeps track of observers and broadcasts state changes to interested parties.
  class ObserveRegistry
    @subscriptions = {}

    class << self
      attr_reader :subscriptions

      def subscribe(path, subscriber)
        @subscriptions[path] ||= []
        @subscriptions[path] << subscriber
      end

      def unsubscribe(path, token)
        return unless @subscriptions[path]

        @subscriptions[path].reject! { |s| s[:token] == token }
      end

      def notify(path, new_value)
        subscribers = @subscriptions[path]
        return unless subscribers

        Takagi.logger.debug "Notify called for: #{path}"
        Takagi.logger.debug "Subscriptions: #{@subscriptions.inspect}"

        subscribers.each do |subscription|
          next unless should_notify?(subscription, new_value)

          deliver_notification(subscription, path, new_value)
          update_sequence(subscription, new_value)
        end
      end

      def sender
        @sender ||= Takagi::Observer::Sender.new
      end

      private

      def should_notify?(subscription, new_value)
        return true unless subscription[:delta] && subscription[:last_value]

        delta_exceeded?(subscription[:last_value], new_value, subscription[:delta])
      end

      def delta_exceeded?(last_value, new_value, threshold)
        (last_value - new_value).abs >= threshold
      rescue StandardError
        true
      end

      def deliver_notification(subscription, path, new_value)
        if subscription[:handler]
          Takagi.logger.debug "Calling local handler for #{path}"
          subscription[:handler].call(new_value, nil)
        else
          Takagi.logger.debug "Sending packet to #{subscription[:address]}:#{subscription[:port]}"
          sender.send_packet(subscription, new_value)
        end
      end

      def update_sequence(subscription, new_value)
        subscription[:last_value] = new_value
        subscription[:last_seq] = (subscription[:last_seq] || 0) + 1
      end
    end
  end
end
