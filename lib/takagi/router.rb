# frozen_string_literal: true

require 'singleton'

module Takagi
  class Router
    include Singleton
    def initialize
      @routes = {}
      @routes_mutex = Mutex.new
    end

    def add_route(method, path, &block)
      @routes_mutex.synchronize do
        @routes["#{method} #{path}"] = block
        puts "[Debug] Add new route: #{method} #{path}"
      end
    end

    def get(path, &block)
      add_route("GET", path, &block)
    end

    def post(path, &block)
      add_route("POST", path, &block)
    end

    def all_routes
      @routes.keys
    end

    def find_route(method, path)
      @routes_mutex.synchronize do
        puts "[Debug] Routes: #{@routes.inspect}"
        puts "[Debug] Looking for route: #{method} #{path}"
        block = @routes["#{method} #{path}"]
        params = {}

        return block.call(params) if block

        puts "[Debug] Find dynamic route"
        block, params = match_dynamic_route(method, path)
        return block.call(params) if block

        Takagi::Message::Outbound.new(code: "4.04 Not Found", payload: {})
      end
    end

    private

    def match_dynamic_route(method, path)
      @routes.each do |route_key, block|
        route_method, route_path = route_key.split(" ", 2)
        next unless route_method == method

        route_parts = route_path.split("/")
        path_parts = path.split("/")
        next unless route_parts.length == path_parts.length

        params = {}
        match = route_parts.each_with_index.all? do |part, index|
          if part.start_with?(":")
            param_name = part[1..]
            params[param_name.to_sym] = path_parts[index]
            true
          else
            part == path_parts[index]
          end
        end
        if match
          puts "[Debug] Match found! Params: #{params.inspect}"
          return block, params
        else
          puts "[Debug] No Match found! Params: #{params.inspect} to #{path}"
        end
      end

      puts "[Debug] No route matched!"
      [nil, {}]
    end
  end
end
