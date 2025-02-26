# frozen_string_literal: true

require "rack"
require "sequel"
require "socket"
require "json"

require_relative 'router'
require_relative 'message'
require_relative 'server'

module Takagi
  class Base < Takagi::Router
    def self.run!(port: 5683)
      Takagi::Server.run!(port: port)
    end
  end
end
