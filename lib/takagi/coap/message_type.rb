# frozen_string_literal: true

require_relative 'registries/message_type'

module Takagi
  module CoAP
    # Backward compatibility alias for Registries::MessageType
    #
    # @deprecated Use {Registries::MessageType} instead. This alias will be removed in v2.0.0
    MessageType = Registries::MessageType
  end
end
