# frozen_string_literal: true

module Takagi
  class Router
    @@routes = {}

    def self.get(path, &block)
      @@routes["GET #{path}"] = block
    end

    def self.post(path, &block)
      @@routes["POST #{path}"] = block
    end

    def self.find_route(method, path)
      return @@routes["#{method} #{path}"], {} if @@routes.key?("#{method} #{path}")

      match_dynamic_route(method, path)
    end

    def self.match_dynamic_route(method, path)
      @@routes.each do |route_key, block|
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

        return [block, params] if match
      end

      [nil, {}]
    end
  end
end
