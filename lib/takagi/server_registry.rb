# frozen_string_literal: true

require_relative 'server/registry'

module Takagi
  # Backward compatibility alias for Server::Registry
  #
  # @deprecated Use {Server::Registry} instead. This alias will be removed in v2.0.0
  ServerRegistry = Server::Registry
end
