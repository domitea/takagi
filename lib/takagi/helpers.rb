# frozen_string_literal: true

module Takagi
  # Helper methods for route handlers to improve DX
  module Helpers
    # CoAP response codes as constants for reference
    module CoAPCodes
      CREATED = '2.01'
      DELETED = '2.02'
      VALID = '2.03'
      CHANGED = '2.04'
      CONTENT = '2.05'
      CONTINUE = '2.31'

      BAD_REQUEST = '4.00'
      UNAUTHORIZED = '4.01'
      BAD_OPTION = '4.02'
      FORBIDDEN = '4.03'
      NOT_FOUND = '4.04'
      METHOD_NOT_ALLOWED = '4.05'
      NOT_ACCEPTABLE = '4.06'
      PRECONDITION_FAILED = '4.12'
      REQUEST_ENTITY_TOO_LARGE = '4.13'
      UNSUPPORTED_CONTENT_FORMAT = '4.15'

      INTERNAL_SERVER_ERROR = '5.00'
      NOT_IMPLEMENTED = '5.01'
      BAD_GATEWAY = '5.02'
      SERVICE_UNAVAILABLE = '5.03'
      GATEWAY_TIMEOUT = '5.04'
      PROXYING_NOT_SUPPORTED = '5.05'
    end

    # Returns a JSON response with 2.05 Content status
    # @param data [Hash] The data to return as JSON
    # @return [Hash] The data hash
    def json(data = {})
      data
    end

    # Returns a 2.01 Created response
    # @param data [Hash] Optional response data
    # @return [Takagi::Message::Outbound]
    def created(data = {})
      request.to_response(CoAPCodes::CREATED, data)
    end

    # Returns a 2.04 Changed response (successful PUT/POST)
    # @param data [Hash] Optional response data
    # @return [Takagi::Message::Outbound]
    def changed(data = {})
      request.to_response(CoAPCodes::CHANGED, data)
    end

    # Returns a 2.02 Deleted response
    # @param data [Hash] Optional response data
    # @return [Takagi::Message::Outbound]
    def deleted(data = {})
      request.to_response(CoAPCodes::DELETED, data)
    end

    # Returns a 2.03 Valid response
    # @param data [Hash] Optional response data
    # @return [Takagi::Message::Outbound]
    def valid(data = {})
      request.to_response(CoAPCodes::VALID, data)
    end

    # Returns a 4.00 Bad Request error
    # @param message [String, Hash] Error message or data
    # @return [Takagi::Message::Outbound]
    def bad_request(message = 'Bad Request')
      data = message.is_a?(Hash) ? message : { error: message }
      request.to_response(CoAPCodes::BAD_REQUEST, data)
    end

    # Returns a 4.01 Unauthorized error
    # @param message [String, Hash] Error message or data
    # @return [Takagi::Message::Outbound]
    def unauthorized(message = 'Unauthorized')
      data = message.is_a?(Hash) ? message : { error: message }
      request.to_response(CoAPCodes::UNAUTHORIZED, data)
    end

    # Returns a 4.03 Forbidden error
    # @param message [String, Hash] Error message or data
    # @return [Takagi::Message::Outbound]
    def forbidden(message = 'Forbidden')
      data = message.is_a?(Hash) ? message : { error: message }
      request.to_response(CoAPCodes::FORBIDDEN, data)
    end

    # Returns a 4.04 Not Found error
    # @param message [String, Hash] Error message or data
    # @return [Takagi::Message::Outbound]
    def not_found(message = 'Not Found')
      data = message.is_a?(Hash) ? message : { error: message }
      request.to_response(CoAPCodes::NOT_FOUND, data)
    end

    # Returns a 4.05 Method Not Allowed error
    # @param message [String, Hash] Error message or data
    # @return [Takagi::Message::Outbound]
    def method_not_allowed(message = 'Method Not Allowed')
      data = message.is_a?(Hash) ? message : { error: message }
      request.to_response(CoAPCodes::METHOD_NOT_ALLOWED, data)
    end

    # Returns a 5.00 Internal Server Error
    # @param message [String, Hash] Error message or data
    # @return [Takagi::Message::Outbound]
    def server_error(message = 'Internal Server Error')
      data = message.is_a?(Hash) ? message : { error: message }
      request.to_response(CoAPCodes::INTERNAL_SERVER_ERROR, data)
    end

    # Returns a 5.03 Service Unavailable error
    # @param message [String, Hash] Error message or data
    # @return [Takagi::Message::Outbound]
    def service_unavailable(message = 'Service Unavailable')
      data = message.is_a?(Hash) ? message : { error: message }
      request.to_response(CoAPCodes::SERVICE_UNAVAILABLE, data)
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
  end
end
