# frozen_string_literal: true

require_relative 'registries/response'

module Takagi
  module CoAP
    # Backward compatibility alias for Registries::Response
    #
    # @deprecated Use {Registries::Response} instead. This alias will be removed in v2.0.0
    Response = Registries::Response
  end
end
