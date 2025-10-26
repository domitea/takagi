# frozen_string_literal: true

module Takagi
  module CoAP
    module Registries
      # CoAP Message Type Registry (RFC 7252 §3)
      #
      # Extensible registry for CoAP message types.
      #
      # @example Using predefined types
      #   Takagi::CoAP::Registries::MessageType::CONFIRMABLE  # => 0
      #   Takagi::CoAP::Registries::MessageType::ACK          # => 2
      #
      # @example Looking up type names
      #   Takagi::CoAP::Registries::MessageType.name_for(0)  # => "Confirmable"
      class MessageType < Base
        # RFC 7252 §3 - Message Format
        register(0, 'Confirmable', :confirmable, rfc: 'RFC 7252 §3')
        register(1, 'Non-confirmable', :non_confirmable, rfc: 'RFC 7252 §3')
        register(2, 'Acknowledgement', :acknowledgement, rfc: 'RFC 7252 §3')
        register(3, 'Reset', :reset, rfc: 'RFC 7252 §3')

        # Aliases for convenience
        CON = CONFIRMABLE
        NON = NON_CONFIRMABLE
        ACK = ACKNOWLEDGEMENT
        RST = RESET

        # Check if type is confirmable
        # @param type [Integer] Message type
        # @return [Boolean] true if confirmable
        def self.confirmable?(type)
          type == CONFIRMABLE
        end

        # Check if type is non-confirmable
        # @param type [Integer] Message type
        # @return [Boolean] true if non-confirmable
        def self.non_confirmable?(type)
          type == NON_CONFIRMABLE
        end

        # Check if type is acknowledgement
        # @param type [Integer] Message type
        # @return [Boolean] true if acknowledgement
        def self.acknowledgement?(type)
          type == ACKNOWLEDGEMENT
        end
        class << self
          alias ack? acknowledgement?
        end

        # Check if type is reset
        # @param type [Integer] Message type
        # @return [Boolean] true if reset
        def self.reset?(type)
          type == RESET
        end

        # Check if type is valid
        # @param type [Integer] Message type
        # @return [Boolean] true if valid
        def self.valid?(type)
          (0..3).include?(type)
        end
      end
    end
  end
end
