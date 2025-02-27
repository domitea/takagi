# frozen_string_literal: true

require "logger"

module Takagi
  class Logger
    @logger = ::Logger.new($stdout)
    @logger.level = ::Logger::INFO

    def self.set_level(level)
      @logger.level = level
    end

    def self.info(message)
      @logger.info(message)
    end

    def self.debug(message)
      @logger.debug(message)
    end

    def self.error(message)
      @logger.error(message)
    end
  end
end
