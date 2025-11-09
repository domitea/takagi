# frozen_string_literal: true

module Takagi
  module Observable
    # Emitter for push-based observable updates
    #
    # Allows observables to push notifications immediately when data changes,
    # rather than relying on polling intervals.
    #
    # @example Event-driven observable
    #   observable '/sensor/temp' do |emitter|
    #     TempSensor.on_change do |reading|
    #       emitter.notify({ temp: reading, unit: 'C' })
    #     end
    #   end
    #
    # @example EventBus integration
    #   observable '/alerts' do |emitter|
    #     emitter.on_event('alert.critical') do |event|
    #       { level: event.severity, message: event.message }
    #     end
    #   end
    class Emitter
      attr_reader :path

      def initialize(path)
        @path = path
      end

      # Push a notification to all observers of this path
      #
      # @param value [Object] The value to send to observers
      # @return [void]
      #
      # @example
      #   emitter.notify({ temp: 25.5, unit: 'C' })
      def notify(value)
        Takagi::Observer::Registry.notify(@path, value)
      end

      # Subscribe to EventBus events and forward to observers
      #
      # @param address [String] EventBus address to subscribe to
      # @yield [event] Optional transform block
      # @return [void]
      #
      # @example Direct forwarding
      #   emitter.on_event('sensor.temp.changed')
      #
      # @example With transformation
      #   emitter.on_event('sensor.temp.changed') do |event|
      #     { temp: event.data[:celsius], timestamp: event.timestamp }
      #   end
      def on_event(address, &transform)
        Takagi::EventBus.subscribe(address) do |event|
          value = transform ? transform.call(event) : event.data
          notify(value)
        end
      end
    end
  end
end
