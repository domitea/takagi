# frozen_string_literal: true

require 'zeitwerk'

# Coap and Ruby in Sinatra like package
module Takagi
  class Error < StandardError; end

  loader = Zeitwerk::Loader.for_gem
  loader.setup
  loader.eager_load
end
