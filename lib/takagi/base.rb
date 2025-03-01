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
  end
end
