# frozen_string_literal: true

require 'singleton'

module Takagi
  class MiddlewareStack
    include Singleton

    def initialize
      @middlewares = []
      @router = Takagi::Router.instance
      load_config
      use(Takagi::Middleware::Debugging.new)
    end

    def use(middleware)
      @middlewares << middleware
    end

    def call(request)
      app = ->(req) { @router.find_route(req.method.to_s, req.uri.path) || req.to_response("4.04 Not Found", { error: "not found" }) }

      @middlewares.reverse.reduce(app) do |next_middleware, middleware|
        ->(req) { middleware.call(req, &next_middleware) }
      end.call(request)
    end

    private

    def load_config
      config_file = "config/middleware.yml"
      return unless File.exist?(config_file)

      config = YAML.load_file(config_file)
      puts "[Debug] Loading Middleware: #{config}"

      config["middlewares"].each do |middleware_name|
        klass = Object.const_get("Takagi::Middleware::#{middleware_name}")
        use(klass.new) if klass
      rescue NameError
        puts "[Warning] Middleware #{middleware_name} nenalezen!"
      end
    end
  end
end

