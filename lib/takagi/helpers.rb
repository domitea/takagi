# frozen_string_literal: true

module Takagi
  # Helper methods for route handlers to improve DX
  #
  # Dynamically generates response helper methods from CoAP::Response registry:
  # - Success methods (2.xx): created(data = {}), changed(data = {}), etc.
  # - Error methods (4.xx, 5.xx): bad_request(message = ...), not_found(message = ...), etc.
  #
  # @example Success response
  #   created({ id: 123, name: 'Resource' })
  #
  # @example Error response
  #   bad_request('Invalid input')
  #   unauthorized({ error: 'Token expired' })
  module Helpers
    # Returns a JSON response with 2.05 Content status
    # @param data [Hash] The data to return as JSON
    # @return [Hash] The data hash
    def json(data = {})
      data
    end

    # Validates that required parameters are present
    # @param required_params [Array<Symbol>] List of required parameter names
    # @raise [StandardError] If any required parameter is missing
    def validate_params(*required_params)
      missing = required_params.select { |param| params[param].nil? }
      return if missing.empty?

      raise ArgumentError, "Missing required parameters: #{missing.join(', ')}"
    end

    # Halts execution and returns the given response
    # Useful for early returns
    # @param response [Takagi::Message::Outbound, Hash] The response to return
    def halt(response)
      throw :halt, response
    end

    # Dynamically generate helper methods from CoAP::Response registry
    # Iterate through all registered response codes
    CoAP::Response.each_value do |code_number|
      code_string = CoAP::Response.name_for(code_number)
      metadata = CoAP::Response.metadata_for(code_number)
      next unless metadata

      symbol = metadata[:symbol]
      next unless symbol

      method_name = symbol.to_s

      # Determine if this is a success (2.xx) or error (4.xx, 5.xx) response
      if CoAP::Response.success?(code_number)
        # Success methods take optional data hash
        define_method(method_name) do |data = {}|
          request.to_response(code_string, data)
        end
      else
        # Error methods take optional message (string or hash)
        default_message = code_string.split(' ', 2)[1] # Extract "Bad Request" from "4.00 Bad Request"

        define_method(method_name) do |message = default_message|
          data = message.is_a?(Hash) ? message : { error: message }
          request.to_response(code_string, data)
        end
      end
    end

    # Alias for internal_server_error (more concise)
    alias server_error internal_server_error
  end
end
