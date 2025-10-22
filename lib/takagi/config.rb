# frozen_string_literal: true

require 'yaml'
require 'logger'

module Takagi
  # Stores runtime configuration loaded from YAML or manual overrides.
  class Config
    Observability = Struct.new(:backends, keyword_init: true)

    attr_accessor :port, :logger, :observability, :auto_migrate, :custom, :processes, :threads, :protocols,
                  :server_name

    def initialize
      @port = 5683
      @logger = Logger.new
      @auto_migrate = true
      @threads = 1
      @processes = 1
      @protocols = [:udp]
      @observability = Observability.new(backends: [:memory])
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
      apply_custom_settings(data)
    end

    private

    def apply_basic_settings(data)
      @port = data['port'] if data['port']
      @processes = data['process'] if data['process']
      @threads = data['threads'] if data['threads']
      @protocols = Array(data['protocols']).map(&:to_sym) if data['protocols']
      @server_name = data['server_name'] if data['server_name']
    end

    def apply_logger(data)
      return unless data['logger']

      @logger = Logger.new
    end

    def apply_observability(data)
      observability = data['observability']
      return unless observability

      backends = Array(observability['backends']).map(&:to_sym)
      @observability.backends = backends if backends.any?
    end

    def apply_custom_settings(data)
      custom_settings = data['custom'] || {}
      custom_settings.each { |key, value| self[key] = value }
    end
  end
end
