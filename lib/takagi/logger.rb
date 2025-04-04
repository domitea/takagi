# frozen_string_literal: true

require 'logger'

module Takagi
  class Logger
    def initialize(log_output: $stdout, level: ::Logger::INFO)
      @logger = ::Logger.new(log_output)
      @logger.level = level
    end

    def set_level(level)
      @logger.level = level
    end

    def info(message)
      @logger.info(message)
    end

    def warn(message)
      @logger.warn(message)
    end

    def debug(message)
      @logger.debug(message)
    end

    def error(message)
      @logger.error(message)
    end
  end
end