# frozen_string_literal: true

require_relative 'registries/method'

module Takagi
  module CoAP
    # Backward compatibility alias for Registries::Method
    #
    # @deprecated Use {Registries::Method} instead. This alias will be removed in v2.0.0
    Method = Registries::Method
  end
end
