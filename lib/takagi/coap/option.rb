# frozen_string_literal: true

require_relative 'registries/option'

module Takagi
  module CoAP
    # Backward compatibility alias for Registries::Option
    #
    # @deprecated Use {Registries::Option} instead. This alias will be removed in v2.0.0
    Option = Registries::Option
  end
end
