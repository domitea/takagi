# frozen_string_literal: true

require 'singleton'

module Takagi
  class Router
    include Singleton
    DEFAULT_CONTENT_FORMAT = 50

    RouteEntry = Struct.new(:method, :path, :block, :metadata, :receiver, keyword_init: true)

    # Provides the execution context for route handlers, exposing helper
    # methods for configuring CoRE Link Format attributes via a small DSL.
    class RouteContext
      attr_reader :request, :params

      def initialize(entry, request, params, receiver)
        @entry = entry
        @request = request
        @params = params
        @receiver = receiver
        @core_attributes = Core::AttributeSet.new(@entry.metadata)
      end

      def metadata
        @core_attributes.metadata
      end

      def run(block)
        return unless block

        args = case block.arity
               when 0 then []
               when 1 then [request]
               else
                 [request, params]
               end
        args = [request, params] if block.arity.negative?

        instance_exec(*args, &block)
      ensure
        @core_attributes.apply!
      end

      def core(&block)
        @core_attributes.core(&block)
      end

      def ct(value)
        @core_attributes.ct(value)
      end
      alias content_format ct

      def sz(value)
        @core_attributes.sz(value)
      end

      def title(value)
        @core_attributes.title(value)
      end

      def obs(value = true)
        @core_attributes.obs(value)
      end
      alias observable obs

      def rt(*values)
        @core_attributes.rt(*values)
      end

      def interface(*values)
        @core_attributes.interface(*values)
      end
      alias if_ interface

      def attribute(name, value)
        @core_attributes.attribute(name, value)
      end

      private

      def method_missing(name, *args, &block)
        if @receiver && @receiver.respond_to?(name)
          @receiver.public_send(name, *args, &block)
        else
          super
        end
      end

      def respond_to_missing?(name, include_private = false)
        (@receiver && @receiver.respond_to?(name, include_private)) || super
      end
    end

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
          return wrap_block(entry), params
        end

        @logger.debug '[Debug] Find dynamic route'
        entry, params = match_dynamic_route(method, path)

        if entry
          return wrap_block(entry), params
        end

        [nil, {}]
      end
    end

    def link_format_entries
      @routes_mutex.synchronize do
        @routes.values.reject { |entry| entry.metadata[:discovery] }.map(&:dup)
      end
    end

    # Applies CoRE metadata outside the request cycle. Useful for boot time
    # configuration where the DSL block does not have a live request object.
    def configure_core(method, path, &block)
      return unless block

      @routes_mutex.synchronize do
        entry = @routes["#{method} #{path}"]
        unless entry
          @logger.warn "configure_core skipped: #{method} #{path} not registered"
          return
        end

        attributes = Core::AttributeSet.new(entry.metadata)
        attributes.core(&block)
        attributes.apply!
      end
    end

    private

    def wrap_block(entry)
      block = entry&.block
      return nil unless block

      ->(req, params = {}) do
        context = RouteContext.new(entry, req, params, entry.receiver)
        context.run(block)
      end
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
      RouteEntry.new(
        method: method,
        path: path,
        block: block,
        metadata: normalize_metadata(method, path, metadata),
        receiver: block&.binding&.receiver
      )
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
