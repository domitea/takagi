# frozen_string_literal: true

require "rack"
require "sequel"
require "socket"
require "json"

module Takagi
  class Base < Takagi::Router
    def self.run!(port: 5683)
      Takagi::Server.new(port: port).run!
    end

    def self.router
      @router ||= Takagi::Router.new
    end

    def self.get(path, &block)
      router.get(path, &block)
    end

    def self.post(path, &block)
      router.post(path, &block)
    end

    def self.call(request)
      middleware_stack.call(request)
    end

    def self.middleware_stack
      @middleware_stack ||= Takagi::MiddlewareStack.new(router)
    end

    def self.use(middleware)
      middleware_stack.use(middleware)
    end
  end
end
