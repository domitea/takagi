# frozen_string_literal: true

module Takagi
  module Registry
    # Thread-safe base module for implementing registries.
    #
    # Provides a consistent API and thread-safety for all registry implementations.
    # Designed to support the plugin system by allowing safe concurrent access.
    #
    # @example Basic usage with class methods
    #   class MyRegistry
    #     extend Takagi::Registry::Base
    #   end
    #
    #   MyRegistry.register(:foo, SomeClass)
    #   MyRegistry.get(:foo)  # => SomeClass
    #   MyRegistry.registered?(:foo)  # => true
    #
    # @example With validation
    #   class MyRegistry
    #     extend Takagi::Registry::Base
    #
    #     def self.validate_entry!(key, value, **metadata)
    #       raise ArgumentError, "Invalid value" unless value.respond_to?(:call)
    #     end
    #   end
    #
    # @example With custom storage structure
    #   class MyRegistry
    #     extend Takagi::Registry::Base
    #
    #     def self.store_entry(key, value, **metadata)
    #       registry[key] = { klass: value, options: metadata }
    #     end
    #   end
    module Base
      # Error raised when a registry entry is not found
      class NotFoundError < StandardError; end

      # Error raised when a registry entry already exists
      class AlreadyRegisteredError < StandardError; end

      # Error raised when validation fails
      class ValidationError < StandardError; end

      def self.extended(base)
        base.instance_variable_set(:@registry, {})
        base.instance_variable_set(:@mutex, Mutex.new)
      end

      # Register a new entry in the registry
      #
      # @param key [Object] Unique identifier for the entry
      # @param value [Object] The value to register
      # @param metadata [Hash] Optional metadata to store with the entry
      # @param overwrite [Boolean] Whether to allow overwriting existing entries
      # @return [void]
      # @raise [AlreadyRegisteredError] If key already exists and overwrite is false
      # @raise [ValidationError] If validation fails
      #
      # @example
      #   MyRegistry.register(:udp, UdpTransport, rfc: 'RFC 7252')
      def register(key, value, overwrite: false, **metadata)
        validate_entry!(key, value, **metadata) if respond_to?(:validate_entry!, true)

        @mutex.synchronize do
          if registry.key?(key) && !overwrite
            raise AlreadyRegisteredError, "#{key} is already registered"
          end

          store_entry(key, value, **metadata)
        end

        after_register(key, value, **metadata) if respond_to?(:after_register, true)
      end

      # Retrieve an entry from the registry
      #
      # @param key [Object] The key to look up
      # @return [Object] The registered value
      # @raise [NotFoundError] If key is not found
      #
      # @example
      #   transport = MyRegistry.get(:udp)
      def get(key)
        value = self[key]
        raise NotFoundError, "#{key} not found in registry" unless value

        value
      end

      # Retrieve an entry from the registry (returns nil if not found)
      #
      # @param key [Object] The key to look up
      # @return [Object, nil] The registered value or nil
      #
      # @example
      #   transport = MyRegistry[:udp]
      def [](key)
        @mutex.synchronize { fetch_entry(key) }
      end

      # Check if a key is registered
      #
      # @param key [Object] The key to check
      # @return [Boolean] true if registered
      #
      # @example
      #   MyRegistry.registered?(:udp)  # => true
      def registered?(key)
        @mutex.synchronize { registry.key?(key) }
      end

      # Get all registered keys
      #
      # @return [Array] List of all keys
      #
      # @example
      #   MyRegistry.keys  # => [:udp, :tcp, :dtls]
      def keys
        @mutex.synchronize { registry.keys.dup }
      end
      alias all keys

      # Get all entries as a hash
      #
      # @return [Hash] Copy of the registry
      #
      # @example
      #   MyRegistry.entries  # => { udp: UdpTransport, tcp: TcpTransport }
      def entries
        @mutex.synchronize { registry.dup }
      end

      # Get metadata for a registered entry
      #
      # @param key [Object] The key to look up
      # @return [Hash, nil] Metadata hash or nil if not found
      #
      # @example
      #   MyRegistry.metadata_for(:udp)  # => { rfc: 'RFC 7252' }
      def metadata_for(key)
        @mutex.synchronize { fetch_metadata(key) }
      end

      # Unregister an entry
      #
      # @param key [Object] The key to remove
      # @return [Object, nil] The removed value or nil if not found
      #
      # @example
      #   MyRegistry.unregister(:udp)
      def unregister(key)
        @mutex.synchronize do
          before_unregister(key) if respond_to?(:before_unregister, true)
          registry.delete(key)
        end
      end

      # Clear all registrations
      #
      # Primarily useful for testing. Thread-safe.
      #
      # @return [void]
      #
      # @example
      #   MyRegistry.clear!
      def clear!
        @mutex.synchronize do
          before_clear if respond_to?(:before_clear, true)
          registry.clear
        end
      end

      # Get count of registered entries
      #
      # @return [Integer] Number of registered entries
      #
      # @example
      #   MyRegistry.count  # => 3
      def count
        @mutex.synchronize { registry.size }
      end
      alias size count

      # Check if registry is empty
      #
      # @return [Boolean] true if no entries registered
      #
      # @example
      #   MyRegistry.empty?  # => false
      def empty?
        @mutex.synchronize { registry.empty? }
      end

      # Iterate over all entries
      #
      # @yield [key, value] Each key-value pair
      # @return [Enumerator] If no block given
      #
      # @example
      #   MyRegistry.each do |key, value|
      #     puts "#{key}: #{value}"
      #   end
      def each(&block)
        return enum_for(:each) unless block_given?

        # Get snapshot to avoid holding lock during iteration
        snapshot = @mutex.synchronize { registry.dup }
        snapshot.each(&block)
      end

      private

      # Access to the internal registry hash
      # Must be called within mutex.synchronize block
      attr_reader :registry

      # Store an entry in the registry (can be overridden)
      #
      # @param key [Object] The key
      # @param value [Object] The value
      # @param metadata [Hash] Metadata
      def store_entry(key, value, **metadata)
        if metadata.empty?
          registry[key] = value
        else
          registry[key] = { value: value, metadata: metadata }
        end
      end

      # Fetch an entry from the registry (can be overridden)
      #
      # @param key [Object] The key
      # @return [Object, nil] The value or nil
      def fetch_entry(key)
        entry = registry[key]
        return nil unless entry

        # Handle both simple values and hash-wrapped values
        entry.is_a?(Hash) && entry.key?(:value) ? entry[:value] : entry
      end

      # Fetch metadata for an entry (can be overridden)
      #
      # @param key [Object] The key
      # @return [Hash, nil] The metadata or nil
      def fetch_metadata(key)
        entry = registry[key]
        return nil unless entry
        return nil unless entry.is_a?(Hash)

        entry[:metadata]
      end
    end
  end
end
