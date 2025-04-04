# frozen_string_literal: true

require 'singleton'

module Takagi
  class Router
    include Singleton
    def initialize
      @routes = {}
      @routes_mutex = Mutex.new # Protects route modifications in multithreaded environments
      @logger = Takagi.logger
    end

    # Registers a new route for a given HTTP method and path
    # @param method [String] The HTTP method (GET, POST, etc.)
    # @param path [String] The URL path, can include dynamic segments like `:id`
    # @param block [Proc] The handler to be executed when the route is matched
    def add_route(method, path, &block)
      @routes_mutex.synchronize do
        @routes["#{method} #{path}"] = block
        @logger.debug "Add new route: #{method} #{path}"
      end
    end

    # Registers a GET route
    # @param path [String] The URL path
    # @param block [Proc] The handler function
    def get(path, &block)
      add_route('GET', path, &block)
    end

    # Registers a POST route
    # @param path [String] The URL path
    # @param block [Proc] The handler function
    def post(path, &block)
      add_route('POST', path, &block)
    end

    # Registers a PUT route
    # @param path [String] The URL path
    # @param block [Proc] The handler function
    def put(path, &block)
      add_route('PUT', path, &block)
    end

    # Registers a DELETE route
    # @param path [String] The URL path
    # @param block [Proc] The handler function
    def delete(path, &block)
      add_route('DELETE', path, &block)
    end

    # Registers a OBSERVE route
    # @param path [String] The URL path
    # @param block [Proc] The handler function
    def observable(path, &block)
      add_route('OBSERVE', path, &block)
    end

    def all_routes
      @routes.keys
    end

    def find_observable(path)
      @routes.find { |key, _| key.start_with?('OBSERVE') && key.split.last == path }
    end

    # Finds a registered route for a given method and path
    # @param method [String] HTTP method
    # @param path [String] URL path
    # @return [Proc, Hash] The matching handler and extracted parameters
    def find_route(method, path)
      @routes_mutex.synchronize do
        @logger.debug "Routes: #{@routes.inspect}"
        @logger.debug "Looking for route: #{method} #{path}"
        block = @routes["#{method} #{path}"]
        params = {}

        if block
          return ->(req) { block.arity == 1 ? block.call(req) : block.call }, params
        end

        @logger.debug '[Debug] Find dynamic route'
        block, params = match_dynamic_route(method, path)

        if block
          return ->(req) { block.arity == 1 ? block.call(req) : block.call }, params
        end

        [nil, {}]
      end
    end

    private

    # Matches dynamic routes that contain parameters (e.g., `/users/:id`)
    # @param method [String] HTTP method
    # @param path [String] Request path
    # @return [Array(Proc, Hash)] Matched route handler and extracted parameters
    def match_dynamic_route(method, path)
      @routes.each do |route_key, block|
        route_method, route_path = route_key.split(' ', 2)
        next unless route_method == method

        route_parts = route_path.split('/')
        path_parts = path.split('/')
        next unless route_parts.length == path_parts.length

        params = {}
        match = route_parts.each_with_index.all? do |part, index|
          if part.start_with?(':')
            param_name = part[1..]
            params[param_name.to_sym] = path_parts[index]
            true
          else
            part == path_parts[index]
          end
        end
        if match
          @logger.debug "Match found! Params: #{params.inspect}"
          return block, params
        else
          @logger.debug "No Match found! Params: #{params.inspect} to #{path}"
        end
      end

      @logger.debug 'No route matched!'
      [nil, {}]
    end
  end
end
