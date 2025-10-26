# frozen_string_literal: true

require_relative 'registries/content_format'

module Takagi
  module CoAP
    # Backward compatibility alias for Registries::ContentFormat
    #
    # @deprecated Use {Registries::ContentFormat} instead. This alias will be removed in v2.0.0
    ContentFormat = Registries::ContentFormat
  end
end
