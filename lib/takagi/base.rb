# frozen_string_literal: true

require 'rack'
require 'socket'
require 'json'

module Takagi
  # Base class that every Takagi based app should use
  class Base < Takagi::Router
    def self.boot!(config_path: 'config/takagi.yml')
      Takagi.config.load_file(config_path) if File.exist?(config_path)
      Takagi::Initializer.run!
    end

    def self.run!(port: nil, config_path: 'config/takagi.yml')
      boot!(config_path: config_path)
      port ||= Takagi.config.port
      processes = Takagi.config.processes
      threads = Takagi.config.threads
      Takagi::Server.new(port: port, worker_processes: processes, worker_threads: threads).run!
    end

    def self.spawn!(port: 5683)
      server = Takagi::Server.new(port: port)
      Thread.new { server.run! }
      server
    end

    def self.router
      @router ||= Takagi::Router.instance
    end

    # Registers a GET route in the global router
    # @param path [String] The URL path
    # @param block [Proc] The request handler
    def self.get(path, &block)
      router.get(path, &block)
    end

    # Registers a POST route in the global router
    # @param path [String] The URL path
    # @param block [Proc] The request handler
    def self.post(path, &block)
      router.post(path, &block)
    end

    # Registers a PUT route in the global router
    # @param path [String] The URL path
    # @param block [Proc] The request handler
    def self.put(path, &block)
      router.put(path, &block)
    end

    # Registers a DELETE route in the global router
    # @param path [String] The URL path
    # @param block [Proc] The request handler
    def self.delete(path, &block)
      router.delete(path, &block)
    end

    def self.call(request)
      middleware_stack.call(request)
    end

    def self.middleware_stack
      @middleware_stack ||= Takagi::MiddlewareStack.load_from_config('', router)
    end

    def self.use(middleware)
      middleware_stack.use(middleware)
    end

    def self.reactor(&block)
      reactor_instance = Takagi::Reactor.new
      reactor_instance.instance_eval(&block)
      Takagi::ReactorRegistry.register(reactor_instance)
    end

    def self.use_reactor(klass)
      reactor_instance = klass.new
      Takagi::ReactorRegistry.register(reactor_instance)
    end

    def self.start_reactors
      Takagi::ReactorRegistry.start_all
    end

    get '/ping' do # basic route for simple checking
      { message: 'Pong' }
    end

    post '/echo' do |req| # testing route for working server
      body = JSON.parse(req.payload || '{}')
      { echo: body['message'] }
    rescue JSON::ParserError
      { error: 'Invalid JSON' }
    end
  end
end
