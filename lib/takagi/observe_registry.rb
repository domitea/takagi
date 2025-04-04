# frozen_string_literal: true

module Takagi
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
        return unless @subscriptions[path]

        Takagi.logger.debug "Notify called for: #{path}"
        Takagi.logger.debug "Subscriptions: #{@subscriptions.inspect}"

        @subscriptions[path].each do |sub|
          should_notify = true

          if sub[:delta] && sub[:last_value]
            delta_diff = (sub[:last_value] - new_value).abs rescue true
            should_notify = delta_diff >= sub[:delta]
          end

          next unless should_notify

          if sub[:handler]
            Takagi.logger.debug "Calling local handler for #{path}"
            sub[:handler].call(new_value, nil)
          else
            Takagi.logger.debug "Sending packet to #{sub[:address]}:#{sub[:port]}"
            sender.send_packet(sub, new_value)
          end

          sub[:last_value] = new_value
          sub[:last_seq] = (sub[:last_seq] || 0) + 1
        end
      end

      def sender
        @sender ||= Takagi::Observer::Sender.new
      end
    end
  end
end