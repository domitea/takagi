# frozen_string_literal: true

require 'rack'
require 'socket'
require 'json'
require_relative 'server/multi'

module Takagi
  # Base class that every Takagi based app should use
  class Base < Takagi::Router
    def self.boot!(config_path: 'config/takagi.yml')
      Takagi.config.load_file(config_path) if File.exist?(config_path)
      Takagi::Initializer.run!
    end

    def self.run!(port: nil, config_path: 'config/takagi.yml', protocols: nil)
      boot!(config_path: config_path)
      selected_port = port || Takagi.config.port
      servers = build_servers(protocols || Takagi.config.protocols, selected_port)
      run_servers(servers)
    end

    def self.spawn!(port: 5683, protocols: nil)
      protos = if protocols
                 Array(protocols)
               else
                 Takagi.config.protocols
               end.map(&:to_sym)

      servers = protos.map do |proto|
        proto == :tcp ? Takagi::Server::Tcp.new(port: port) : Takagi::Server::Udp.new(port: port)
      end

      if servers.length == 1
        Thread.new { servers.first.run! }
        servers.first
      else
        multi = Takagi::Server::Multi.new(servers)
        Thread.new { multi.run! }
        multi
      end
    end

    def self.router
      @router ||= Takagi::Router.instance
    end

    # Registers a GET route in the global router
    # @param path [String] The URL path
    # @param block [Proc] The request handler
    def self.get(path, metadata: {}, &block)
      router.get(path, metadata: metadata, &block)
    end

    # Registers a POST route in the global router
    # @param path [String] The URL path
    # @param block [Proc] The request handler
    def self.post(path, metadata: {}, &block)
      router.post(path, metadata: metadata, &block)
    end

    # Registers a PUT route in the global router
    # @param path [String] The URL path
    # @param block [Proc] The request handler
    def self.put(path, metadata: {}, &block)
      router.put(path, metadata: metadata, &block)
    end

    # Registers a DELETE route in the global router
    # @param path [String] The URL path
    # @param block [Proc] The request handler
    def self.delete(path, metadata: {}, &block)
      router.delete(path, metadata: metadata, &block)
    end

    # Registers an OBSERVE route in the global router
    # @param path [String] The URL path
    # @param block [Proc] The handler function
    def self.observable(path, metadata: {}, &block)
      router.observable(path, metadata: metadata, &block)
    end

    def self.core(path, method: :get, &block)
      router.configure_core(method.to_s.upcase, path, &block)
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

    get '/.well-known/core', metadata: {
      rt: 'core.discovery',
      if: 'core.rd',
      ct: Takagi::Discovery::CoreLinkFormat::CONTENT_FORMAT,
      discovery: true,
      title: 'Resource Discovery'
    } do |req|
      payload = Takagi::Discovery::CoreLinkFormat.generate(router: router, request: req)
      req.to_response(
        '2.05 Content',
        payload,
        options: { 12 => Takagi::Discovery::CoreLinkFormat::CONTENT_FORMAT }
      )
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

    class << self
      private

      def build_servers(protocols, port)
        threads = Takagi.config.threads
        processes = Takagi.config.processes
        Array(protocols).map(&:to_sym).map do |protocol|
          instantiate_server(protocol, port, threads: threads, processes: processes)
        end
      end

      def instantiate_server(protocol, port, threads:, processes:)
        case protocol
        when :tcp
          Takagi::Server::Tcp.new(port: port, worker_threads: threads)
        else
          Takagi::Server::Udp.new(port: port, worker_processes: processes, worker_threads: threads)
        end
      end

      def run_servers(servers)
        return servers.first.run! if servers.length == 1

        Takagi::Server::Multi.new(servers).run!
      end
    end
  end
end
