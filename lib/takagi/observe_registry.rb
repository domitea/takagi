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

        @subscriptions[path].each do |sub|
          should_notify = true

          if sub[:delta] && sub[:last_value]
            delta_diff = (sub[:last_value] - new_value).abs
            should_notify = delta_diff >= sub[:delta]
          end

          next unless should_notify

          Takagi.logger.debug "Notifying #{sub[:address]}:#{sub[:port]} about #{path} = #{new_value}"
          sender.send_packet(sub, new_value)
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