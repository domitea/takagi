# frozen_string_literal: true

require 'zeitwerk'

module Takagi
  class Error < StandardError; end

  loader = Zeitwerk::Loader.for_gem
  loader.setup
  loader.eager_load
end
