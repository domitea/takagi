# frozen_string_literal: true

module Takagi
  class MiddlewareStack
    def initialize
      @middlewares = []
    end

    def use(middleware)
      @middlewares << middleware
    end

    def call(request)
      @middlewares.reduce(request) { |req, middleware| middleware.call(req) }
    end

    def self.load_from_config(config_file)
      config = YAML.load_file(config_file)
      stack = new

      config["middlewares"].each do |middleware|
        klass = Object.const_get("Takagi::#{middleware}")
        stack.use(klass.new) if klass
      end

      stack
    end
  end
end
