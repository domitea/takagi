# frozen_string_literal: true

module Takagi
  class Router
    # Handles dynamic route matching with parameter extraction.
    #
    # Extracted from Router to follow Single Responsibility Principle.
    # Manages matching URL patterns with dynamic segments (e.g., /users/:id)
    # and extracting parameters from matched routes.
    class RouteMatcher
      # @param logger [Logger] Logger instance for debugging
      def initialize(logger)
        @logger = logger
      end

      # Matches dynamic routes that contain parameters (e.g., `/users/:id`)
      #
      # @param routes [Hash] Map of route keys to RouteEntry objects
      # @param method [String] HTTP method
      # @param path [String] Request path
      # @return [Array(RouteEntry, Hash), Array(nil, Hash)] Matched route entry and parameters, or [nil, {}]
      def match(routes, method, path)
        matched_route = locate_dynamic_route(routes, method, path)
        return matched_route if matched_route

        @logger.debug 'No route matched!'
        [nil, {}]
      end

      private

      # Locates a dynamic route by iterating through all routes
      #
      # @param routes [Hash] All registered routes
      # @param method [String] HTTP method to match
      # @param path [String] Request path to match
      # @return [Array(RouteEntry, Hash), nil] Matched entry and params, or nil
      def locate_dynamic_route(routes, method, path)
        routes.each_value do |entry|
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

      # Extracts dynamic parameters from a route pattern
      #
      # Compares route pattern (e.g., /users/:id) with actual path (e.g., /users/123)
      # and extracts parameter values.
      #
      # @param route_path [String] Route pattern with :param segments
      # @param path [String] Actual request path
      # @return [Hash, nil] Extracted parameters or nil if no match
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
            @logger.debug "No Match found! Params: #{params.inspect} to #{path}"
            matched = false
            break
          end
        end

        matched ? params : nil
      end
    end
  end
end
