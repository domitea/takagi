# frozen_string_literal: true

require_relative 'observer/registry'

module Takagi
  # Backward compatibility alias for Observer::Registry
  #
  # @deprecated Use {Observer::Registry} instead. This alias will be removed in v2.0.0
  ObserveRegistry = Observer::Registry
end
