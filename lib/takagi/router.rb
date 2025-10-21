# frozen_string_literal: true

require 'singleton'

module Takagi
  class Router
    include Singleton
    DEFAULT_CONTENT_FORMAT = 50

    RouteEntry = Struct.new(:method, :path, :block, :metadata, keyword_init: true)

    def initialize
      @routes = {}
      @routes_mutex = Mutex.new # Protects route modifications in multithreaded environments
      @logger = Takagi.logger
    end

    # Registers a new route for a given HTTP method and path
    # @param method [String] The HTTP method (GET, POST, etc.)
    # @param path [String] The URL path, can include dynamic segments like `:id`
    # @param block [Proc] The handler to be executed when the route is matched
    def add_route(method, path, metadata: {}, &block)
      @routes_mutex.synchronize do
        entry = build_route_entry(method, path, metadata, block)
        @routes["#{method} #{path}"] = entry
        @logger.debug "Add new route: #{method} #{path}"
      end
    end

    # Registers a GET route
    # @param path [String] The URL path
    # @param block [Proc] The handler function
    def get(path, metadata: {}, &block)
      add_route('GET', path, metadata: metadata, &block)
    end

    # Registers a POST route
    # @param path [String] The URL path
    # @param block [Proc] The handler function
    def post(path, metadata: {}, &block)
      add_route('POST', path, metadata: metadata, &block)
    end

    # Registers a PUT route
    # @param path [String] The URL path
    # @param block [Proc] The handler function
    def put(path, metadata: {}, &block)
      add_route('PUT', path, metadata: metadata, &block)
    end

    # Registers a DELETE route
    # @param path [String] The URL path
    # @param block [Proc] The handler function
    def delete(path, metadata: {}, &block)
      add_route('DELETE', path, metadata: metadata, &block)
    end

    # Registers a OBSERVE route
    # @param path [String] The URL path
    # @param block [Proc] The handler function
    def observable(path, metadata: {}, &block)
      observable_metadata = { obs: true, rt: 'core#observable', if: 'takagi.observe' }
      add_route('OBSERVE', path, metadata: observable_metadata.merge(metadata), &block)
    end

    def all_routes
      @routes.values.map { |entry| "#{entry.method} #{entry.path}" }
    end

    def find_observable(path)
      @routes.values.find { |entry| entry.method == 'OBSERVE' && entry.path == path }
    end

    # Finds a registered route for a given method and path
    # @param method [String] HTTP method
    # @param path [String] URL path
    # @return [Proc, Hash] The matching handler and extracted parameters
    def find_route(method, path)
      @routes_mutex.synchronize do
        @logger.debug "Routes: #{@routes.inspect}"
        @logger.debug "Looking for route: #{method} #{path}"
        entry = @routes["#{method} #{path}"]
        params = {}

        if entry
          return wrap_block(entry.block), params
        end

        @logger.debug '[Debug] Find dynamic route'
        entry, params = match_dynamic_route(method, path)

        if entry
          return wrap_block(entry.block), params
        end

        [nil, {}]
      end
    end

    def link_format_entries
      @routes_mutex.synchronize do
        @routes.values.reject { |entry| entry.metadata[:discovery] }.map(&:dup)
      end
    end

    private

    def wrap_block(block)
      ->(req) { block.arity == 1 ? block.call(req) : block.call }
    end

    # Matches dynamic routes that contain parameters (e.g., `/users/:id`)
    # @param method [String] HTTP method
    # @param path [String] Request path
    # @return [Array(Proc, Hash)] Matched route handler and extracted parameters
    def match_dynamic_route(method, path)
      matched_route = locate_dynamic_route(method, path)
      return matched_route if matched_route

      @logger.debug 'No route matched!'
      [nil, {}]
    end

    def locate_dynamic_route(method, path)
      @routes.each_value do |entry|
        route_method = entry.method
        route_path = entry.path
        next unless route_method == method

        params = extract_dynamic_params(route_path, path)
        next unless params

        @logger.debug "Match found! Params: #{params.inspect}"
        return [entry, params]
      end
      nil
    end

    def extract_dynamic_params(route_path, path)
      route_parts = route_path.split('/')
      path_parts = path.split('/')
      return unless route_parts.length == path_parts.length

      params = {}
      matched = true

      route_parts.each_with_index do |part, index|
        if part.start_with?(':')
          params[part[1..].to_sym] = path_parts[index]
        elsif part != path_parts[index]
          log_no_match(params, path)
          matched = false
          break
        end
      end

      matched ? params : nil
    end

    def log_no_match(params, path)
      @logger.debug "No Match found! Params: #{params.inspect} to #{path}"
    end

    def build_route_entry(method, path, metadata, block)
      RouteEntry.new(method: method, path: path, block: block, metadata: normalize_metadata(method, path, metadata))
    end

    def normalize_metadata(method, path, metadata)
      normalized = (metadata || {}).transform_keys(&:to_sym)
      normalized[:rt] ||= default_resource_type(method)
      normalized[:if] ||= default_interface(method)
      normalized[:ct] = DEFAULT_CONTENT_FORMAT unless normalized.key?(:ct)
      normalized[:title] ||= "#{method} #{path}"
      normalized
    end

    def default_resource_type(method)
      method == 'OBSERVE' ? 'core#observable' : 'core#endpoint'
    end

    def default_interface(method)
      method == 'OBSERVE' ? 'takagi.observe' : "takagi.#{method.downcase}"
    end
  end
end
