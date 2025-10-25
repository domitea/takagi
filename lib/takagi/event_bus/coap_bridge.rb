# frozen_string_literal: true

require 'set'
require 'securerandom'

module Takagi
  class EventBus
    # CoAP Observe integration - maps events to CoAP resources
    # Thread-safe with Mutex for resource registration
    #
    # Maps EventBus addresses to CoAP observable resources:
    # - "sensor.temperature.room1" -> "/events/sensor/temperature/room1"
    #
    # @example
    #   CoAPBridge.register_observable_resource('sensor.temp.room1', app)
    #   CoAPBridge.publish_to_observers('sensor.temp.room1', message)
    class CoAPBridge
      @registered_resources = Set.new
      @mutex = Mutex.new

      class << self
        # Convert event address to CoAP path
        # @param address [String] Event address (e.g., "sensor.temperature.room1")
        # @return [String] CoAP path (e.g., "/events/sensor/temperature/room1")
        #
        # @example
        #   CoAPBridge.address_to_path('sensor.temperature.room1')
        #   # => "/events/sensor/temperature/room1"
        def address_to_path(address)
          "/events/#{address.gsub('.', '/')}"
        end

        # Convert CoAP path to event address
        # @param path [String] CoAP path (e.g., "/events/sensor/temperature/room1")
        # @return [String] Event address (e.g., "sensor.temperature.room1")
        #
        # @example
        #   CoAPBridge.path_to_address('/events/sensor/temperature/room1')
        #   # => "sensor.temperature.room1"
        def path_to_address(path)
          path.sub(%r{^/events/}, '').gsub('/', '.')
        end

        # Auto-register observable CoAP resource (thread-safe)
        # Creates a CoAP observable endpoint that returns current state
        #
        # Uses AddressPrefix registry to determine if address should be distributed
        #
        # @param address [String] Event address
        # @param app [Class] Application class (must respond to #observable)
        # @return [Boolean] True if registered, false if already exists
        #
        # @example
        #   CoAPBridge.register_observable_resource('sensor.temp.room1', MyApp)
        def register_observable_resource(address, app) # rubocop:disable Metrics/MethodLength
          # Only register distributed addresses (uses AddressPrefix registry)
          return false unless AddressPrefix.distributed?(address)

          # Thread-safe check-and-register
          @mutex.synchronize do
            # Already registered?
            return false if @registered_resources.include?(address)

            # Mark as registered before creating resource
            @registered_resources << address

            path = address_to_path(address)

            begin
              # Create observable CoAP endpoint
              # This endpoint returns current state when polled
              app.observable path do |_req|
                # Return current state from EventBus
                current_state = EventBus.current_state(address)

                current_state || {
                  address: address,
                  status: 'observable',
                  timestamp: Time.now.to_i
                }
              end

              Takagi.logger.info "Observable resource created: #{path} (#{address})"
              true
            rescue StandardError => e
              # If registration fails, remove from set
              @registered_resources.delete(address)
              Takagi.logger.error "Failed to register observable resource #{address}: #{e.message}"
              false
            end
          end
        end

        # Publish event to all CoAP observers
        # Notifies all observers subscribed via CoAP Observe
        #
        # @param address [String] Event address
        # @param message [EventBus::Message] Event message
        #
        # @example
        #   message = EventBus::Message.new('sensor.temp.room1', { value: 25.5 })
        #   CoAPBridge.publish_to_observers('sensor.temp.room1', message)
        def publish_to_observers(address, message)
          path = address_to_path(address)

          # Build notification payload
          state = {
            address: address,
            body: message.body,
            headers: message.headers,
            timestamp: message.timestamp.to_i
          }

          # Notify via ObserveRegistry
          # ObserveRegistry will send CoAP notifications to all observers
          if defined?(Takagi::ObserveRegistry)
            Takagi::ObserveRegistry.notify(path, state)
          else
            Takagi.logger.warn 'ObserveRegistry not available, cannot publish to observers'
          end
        rescue StandardError => e
          Takagi.logger.error "Error publishing to observers for #{address}: #{e.message}"
        end

        # Subscribe to remote event via CoAP Observe
        # @param address [String] Event address
        # @param node_url [String] Remote node URL (e.g., 'coap://building-a:5683')
        # @yield [message] Block called when remote notification received
        # @return [String] Subscription ID
        #
        # @example
        #   id = CoAPBridge.subscribe_remote('sensor.temp.buildingA', 'coap://building-a:5683') do |msg|
        #     puts "Remote temp: #{msg.body[:value]}"
        #   end
        def subscribe_remote(address, node_url)
          path = address_to_path(address)
          full_url = "#{node_url}#{path}"

          # TODO: Implement using Takagi::Observer::Client or similar
          # This requires:
          # 1. CoAP client that supports OBSERVE requests
          # 2. Registration of observer with remote server
          # 3. Handling of notification messages
          # 4. Conversion of CoAP notifications back to EventBus messages
          #
          # Placeholder implementation:
          subscription_id = SecureRandom.uuid

          Takagi.logger.warn "Remote subscription not yet fully implemented: #{full_url}"
          Takagi.logger.info "Subscription ID: #{subscription_id} for #{address} at #{node_url}"

          # When implemented, should:
          # 1. Create CoAP observer client
          # 2. Send OBSERVE request to full_url
          # 3. Register callback that converts CoAP notifications to EventBus messages
          # 4. Call the provided block with the converted message

          subscription_id
        end

        # Check if resource is registered
        # @param address [String] Event address
        # @return [Boolean]
        def registered?(address)
          @mutex.synchronize { @registered_resources.include?(address) }
        end

        # Get all registered resource addresses
        # @return [Array<String>]
        def registered_addresses
          @mutex.synchronize { @registered_resources.to_a }
        end

        # Get count of registered resources
        # @return [Integer]
        def registered_count
          @mutex.synchronize { @registered_resources.size }
        end

        # Unregister a resource (for testing)
        # @param address [String] Event address
        # @return [Boolean] True if was registered
        def unregister(address)
          @mutex.synchronize do
            @registered_resources.delete?(address) || false
          end
        end

        # Clear all registrations (for testing)
        def clear
          @mutex.synchronize do
            @registered_resources.clear
          end
        end
      end
    end
  end
end
