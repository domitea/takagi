# frozen_string_literal: true

class Config
  require 'yaml'
  require 'logger'
  require 'ostruct'

  module Takagi
    class Config
      attr_accessor :port, :logger, :observability, :auto_migrate, :custom

      def initialize
        @port = 5683
        @logger = Logger.new($stdout)
        @auto_migrate = true
        @observability = OpenStruct.new(backends: [:memory])
        @custom = {}
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
          super
        end
      end

      def respond_to_missing?(name, include_private = false)
        key = name.to_s.chomp('=').to_sym
        @custom.key?(key) || super
      end

      def load_file(path)
        data = YAML.load_file(path)

        @port = data['port'] if data['port']
        @logger = Logger.new(data['logger']) if data['logger']
        if data['observability']
          @observability.backends = data['observability']['backends'].map(&:to_sym)
        end
        data['custom']&.each { |k, v| self[k] = v }
      end
    end

    def self.config
      @config ||= Config.new
    end

    def self.configure
      yield(config)
    end
  end

end
