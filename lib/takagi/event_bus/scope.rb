# frozen_string_literal: true

module Takagi
  class EventBus
    # Message scope levels for clustering support
    #
    # LOCAL: Message stays on this instance only
    # CLUSTER: Message delivered to all instances in cluster
    # GLOBAL: Message delivered to cluster + external CoAP subscribers
    #
    # @example Local event (default)
    #   EventBus.publish('system.startup', data, scope: :local)
    #
    # @example Cluster-wide event
    #   EventBus.publish('cache.invalidate', { key: 'user:123' }, scope: :cluster)
    #
    # @example Global event (cluster + external)
    #   EventBus.publish('sensor.temperature', { value: 25.5 }, scope: :global)
    module Scope
      # This instance only - never leaves process
      LOCAL = :local

      # All instances in cluster - distributed via CoAP OBSERVE
      CLUSTER = :cluster

      # Cluster + external CoAP subscribers - published to /.well-known/core
      GLOBAL = :global

      # Default scope if not specified
      DEFAULT = LOCAL

      # All valid scope values
      ALL = [LOCAL, CLUSTER, GLOBAL].freeze

      # Check if scope is valid
      # @param scope [Symbol] Scope to check
      # @return [Boolean]
      def self.valid?(scope)
        ALL.include?(scope)
      end

      # Normalize scope value
      # @param scope [Symbol, String, nil] Scope to normalize
      # @return [Symbol] Normalized scope (defaults to LOCAL)
      def self.normalize(scope)
        return DEFAULT if scope.nil?

        scope_sym = scope.to_sym
        valid?(scope_sym) ? scope_sym : DEFAULT
      end

      # Check if scope requires cluster distribution
      # @param scope [Symbol] Scope to check
      # @return [Boolean]
      def self.distributed?(scope)
        scope == CLUSTER || scope == GLOBAL
      end

      # Check if scope allows external CoAP subscribers
      # @param scope [Symbol] Scope to check
      # @return [Boolean]
      def self.external?(scope)
        scope == GLOBAL
      end

      # Check if scope is local-only
      # @param scope [Symbol] Scope to check
      # @return [Boolean]
      def self.local_only?(scope)
        scope == LOCAL
      end
    end
  end
end
