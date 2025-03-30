# frozen_string_literal: true

require 'zeitwerk'

# Coap and Ruby in Sinatra like package
module Takagi
  class Error < StandardError; end

  def self.config
    @config ||= Takagi::Config.new
  end

  def self.logger
    @logger ||= Takagi::Logger.new
  end

  loader = Zeitwerk::Loader.for_gem
  loader.setup
  loader.eager_load


end
