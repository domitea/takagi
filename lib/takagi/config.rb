# frozen_string_literal: true

require 'yaml'
require 'logger'

module Takagi
  # Stores runtime configuration loaded from YAML or manual overrides.
  class Config
    Observability = Struct.new(:backends, keyword_init: true)
    EventBusConfig = Struct.new(
      :ractors,
      :state_cache_size,
      :state_cache_ttl,
      :cleanup_interval,
      :max_observer_age,
      :message_buffering_enabled,
      :message_buffer_max_messages,
      :message_buffer_ttl,
      keyword_init: true
    )
    RouterConfig = Struct.new(
      :default_content_format,
      keyword_init: true
    )
    MiddlewareConfig = Struct.new(
      :enabled,
      :stack,
      keyword_init: true
    )

    attr_accessor :port, :bind_address, :logger, :observability, :auto_migrate, :custom, :processes, :threads,
                  :protocols, :server_name, :event_bus, :router, :middleware

    def initialize
      @port = 5683
      @bind_address = '0.0.0.0'  # Bind to all interfaces by default
      @logger = ::Logger.new($stdout)
      @auto_migrate = true
      @threads = 1
      @processes = 1
      @protocols = [:udp]
      @observability = Observability.new(backends: [:memory])
      @event_bus = EventBusConfig.new(
        ractors: 10,
        state_cache_size: 1000,
        state_cache_ttl: 3600,
        cleanup_interval: 60,
        max_observer_age: 600,
        message_buffering_enabled: false,
        message_buffer_max_messages: 100,
        message_buffer_ttl: 300
      )
      @router = RouterConfig.new(
        default_content_format: 50  # application/json
      )
      @middleware = MiddlewareConfig.new(
        enabled: true,
        stack: default_middleware_stack
      )
      @custom = {}
      @server_name = nil
    end

    def [](key)
      @custom[key.to_sym]
    end

    def []=(key, value)
      @custom[key.to_sym] = value
    end

    def method_missing(name, *args, &block)
      key = name.to_s.chomp('=').to_sym
      if name.to_s.end_with?('=')
        @custom[key] = args.first
      elsif @custom.key?(key)
        @custom[key]
      else
        super(&block)
      end
    end

    def respond_to_missing?(name, include_private = false)
      key = name.to_s.chomp('=').to_sym
      @custom.key?(key) || super
    end

    def load_file(path)
      data = YAML.load_file(path) || {}

      apply_basic_settings(data)
      apply_logger(data)
      apply_observability(data)
      apply_event_bus(data)
      apply_router(data)
      apply_middleware(data)
      apply_custom_settings(data)
    end

    private

    def apply_basic_settings(data)
      @port = data['port'] if data['port']
      @bind_address = data['bind_address'] if data['bind_address']
      @processes = data['process'] if data['process']
      @threads = data['threads'] if data['threads']
      @protocols = Array(data['protocols']).map(&:to_sym) if data['protocols']
      @server_name = data['server_name'] if data['server_name']
    end

    def apply_logger(data)
      return unless data['logger']

      @logger = ::Logger.new($stdout)
    end

    def apply_observability(data)
      observability = data['observability']
      return unless observability

      backends = Array(observability['backends']).map(&:to_sym)
      @observability.backends = backends if backends.any?
    end

    def apply_event_bus(data)
      event_bus_data = data['event_bus']
      return unless event_bus_data

      # Core EventBus settings
      @event_bus.ractors = event_bus_data['ractors'] if event_bus_data['ractors']
      @event_bus.state_cache_size = event_bus_data['state_cache_size'] if event_bus_data['state_cache_size']
      @event_bus.state_cache_ttl = event_bus_data['state_cache_ttl'] if event_bus_data['state_cache_ttl']
      @event_bus.cleanup_interval = event_bus_data['cleanup_interval'] if event_bus_data['cleanup_interval']
      @event_bus.max_observer_age = event_bus_data['max_observer_age'] if event_bus_data['max_observer_age']

      # Message buffering settings
      if event_bus_data.key?('message_buffering_enabled')
        @event_bus.message_buffering_enabled = event_bus_data['message_buffering_enabled']
      end
      if event_bus_data['message_buffer_max_messages']
        @event_bus.message_buffer_max_messages = event_bus_data['message_buffer_max_messages']
      end
      @event_bus.message_buffer_ttl = event_bus_data['message_buffer_ttl'] if event_bus_data['message_buffer_ttl']
    end

    def apply_router(data)
      router_data = data['router']
      return unless router_data

      if router_data['default_content_format']
        @router.default_content_format = router_data['default_content_format']
      end
    end

    def apply_middleware(data)
      middleware_data = data['middleware']
      return unless middleware_data

      # Enable/disable middleware globally
      @middleware.enabled = middleware_data['enabled'] if middleware_data.key?('enabled')

      # Load middleware stack from config
      if middleware_data['stack']
        @middleware.stack = middleware_data['stack'].map do |middleware_config|
          parse_middleware_entry(middleware_config)
        end
      end
    end

    def apply_custom_settings(data)
      custom_settings = data['custom'] || {}
      custom_settings.each { |key, value| self[key] = value }
    end

    # Parse middleware entry from YAML config
    # Supports both simple strings and hash with options
    #
    # @example Simple string
    #   "Logging"
    #
    # @example Hash with options
    #   { name: "Caching", options: { ttl: 300 } }
    def parse_middleware_entry(entry)
      case entry
      when String
        { name: entry, options: {} }
      when Hash
        {
          name: entry['name'] || entry[:name],
          options: entry['options'] || entry[:options] || {}
        }
      else
        raise ArgumentError, "Invalid middleware entry: #{entry.inspect}"
      end
    end

    # Default middleware stack
    # Returns an array of middleware configurations
    def default_middleware_stack
      [
        { name: 'Debugging', options: {} }
      ]
    end
  end
end
