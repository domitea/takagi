# frozen_string_literal: true

require 'singleton'

module Takagi
  # even Sinatra like app needs middleware..
  class MiddlewareStack
    include Singleton

    def initialize
      @logger = Takagi.logger
      @middlewares = []
      @router = Takagi::Router.instance
      load_config
      use(Takagi::Middleware::Debugging.new)
    end

    # Adds a new middleware to the stack
    # @param middleware [Object] Middleware instance that responds to `call`
    def use(middleware)
      @middlewares << middleware
    end

    # Processes the request through the middleware stack and routes it
    # @param request [Takagi::Message::Inbound] Incoming request object
    # @return [Takagi::Message::Outbound] The final processed response
    def call(request)
      app = lambda do |req|
        block, params = @router.find_route(req.method.to_s, req.uri.path)
        if block
          block.arity == 2 ? block.call(req, params) : block.call(req)
        else
          req.to_response('4.04 Not Found', { error: 'not found' })
        end
      end

      @middlewares.reverse.reduce(app) do |next_middleware, middleware|
        ->(req) { middleware.call(req, &next_middleware) }
      end.call(request)
    end

    private

    # Loads middleware stack from a configuration file
    def load_config
      config_file = 'config/middleware.yml'
      return unless File.exist?(config_file)

      config = YAML.load_file(config_file)
      @logger.debug "Loading Middleware: #{config}"

      config['middlewares'].each do |middleware_name|
        klass = Object.const_get("Takagi::Middleware::#{middleware_name}")
        use(klass.new) if klass
      rescue NameError
        @logger.warn "Middleware #{middleware_name} not found!"
      end
    end
  end
end
