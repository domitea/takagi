# frozen_string_literal: true

module Takagi
  class EventBus
    # EventBus Address Prefix Registry
    #
    # Defines which event address prefixes are distributed via CoAP
    # and which remain local-only.
    #
    # Extensible registry allows plugins to register custom prefixes
    # without modifying core code.
    #
    # @example Using predefined prefixes
    #   AddressPrefix.distributed?('sensor.temperature.room1')  # => true
    #   AddressPrefix.distributed?('system.startup')            # => false
    #
    # @example Registering a custom distributed prefix
    #   AddressPrefix.register_distributed('custom.', 'Custom Events')
    #
    # @example Registering a custom local prefix
    #   AddressPrefix.register_local('internal.', 'Internal Events')
    class AddressPrefix
      @distributed = {}
      @local = {}
      @mutex = Mutex.new

      class << self
        # Register a distributed prefix (events are published via CoAP)
        # @param prefix [String] Address prefix (e.g., 'sensor.')
        # @param description [String] Human-readable description
        # @param rfc [String, nil] Optional RFC reference
        def register_distributed(prefix, description, rfc: nil)
          @mutex.synchronize do
            @distributed[prefix] = {
              description: description,
              rfc: rfc,
              type: :distributed
            }
          end
        end

        # Register a local-only prefix (events stay in-process)
        # @param prefix [String] Address prefix (e.g., 'system.')
        # @param description [String] Human-readable description
        # @param rfc [String, nil] Optional RFC reference
        def register_local(prefix, description, rfc: nil)
          @mutex.synchronize do
            @local[prefix] = {
              description: description,
              rfc: rfc,
              type: :local
            }
          end
        end

        # Check if address matches a distributed prefix
        # @param address [String] Event address
        # @return [Boolean] true if distributed
        def distributed?(address)
          return false if local?(address)

          @mutex.synchronize do
            @distributed.keys.any? { |prefix| address.start_with?(prefix) }
          end
        end

        # Check if address matches a local-only prefix
        # @param address [String] Event address
        # @return [Boolean] true if local-only
        def local?(address)
          @mutex.synchronize do
            @local.keys.any? { |prefix| address.start_with?(prefix) }
          end
        end

        # Get all distributed prefixes
        # @return [Hash] Map of prefix => metadata
        def distributed_prefixes
          @mutex.synchronize { @distributed.dup }
        end

        # Get all local prefixes
        # @return [Hash] Map of prefix => metadata
        def local_prefixes
          @mutex.synchronize { @local.dup }
        end

        # Get all registered prefixes
        # @return [Hash] Combined map of all prefixes
        def all
          @mutex.synchronize do
            @distributed.merge(@local)
          end
        end

        # Get metadata for a specific prefix
        # @param prefix [String] The prefix to look up
        # @return [Hash, nil] Prefix metadata
        def metadata_for(prefix)
          @mutex.synchronize do
            @distributed[prefix] || @local[prefix]
          end
        end

        # Unregister a prefix (useful for testing/plugins)
        # @param prefix [String] The prefix to remove
        # @return [Boolean] true if was registered
        def unregister(prefix)
          @mutex.synchronize do
            @distributed.delete(prefix) || @local.delete(prefix)
          end
        end

        # Clear all registrations (useful for testing)
        def clear!
          @mutex.synchronize do
            @distributed.clear
            @local.clear
          end
        end

        # Initialize default prefixes
        def initialize_defaults!
          # Distributed prefixes (published via CoAP Observe)
          register_distributed('sensor.', 'Sensor Events', rfc: 'RFC 7641')
          register_distributed('alert.', 'Alert Events', rfc: 'RFC 7641')
          register_distributed('cluster.', 'Cluster Events')
          register_distributed('reactor.', 'Reactor Events')
          register_distributed('event.', 'General Events')

          # Local-only prefixes (stay in-process)
          register_local('system.', 'System Events')
          register_local('coap.', 'CoAP Protocol Events')
          register_local('plugin.', 'Plugin Lifecycle Events')
        end
      end

      # Initialize defaults when class is loaded
      initialize_defaults!
    end
  end
end
