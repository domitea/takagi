# frozen_string_literal: true

module Takagi
  class MiddlewareStack
    def initialize
      @middlewares = []
      @router = Router.new
    end

    def use(middleware)
      @middlewares << middleware
    end

    def call(request)
      app = ->(req) { @router.find_route(req, req.uri) || req.to_response("4.04 Not Found", { error: "not found" }) }

      @middlewares.reverse.reduce(app) do |next_middleware, middleware|
        ->(req) { middleware.call(req, &next_middleware) }
      end.call(request)
    end

    def self.load_from_config(config_file)
      config = (YAML.load_file(config_file) if File.exist?(config_file))
      stack = new

      stack.use(Takagi::Middleware::Debugging.new) # for testing now...

      unless config.nil?
        config["middlewares"].each do |middleware|
          klass = Object.const_get("Takagi::Middleware::#{middleware}")
          stack.use(klass.new) if klass
        end
      end

      stack
    end
  end
end
