# frozen_string_literal: true

module Takagi
  # Builds CoAP responses from middleware results
  class ResponseBuilder
    # Builds a response from the middleware result
    #
    # @param inbound_request [Takagi::Message::Inbound] The original request
    # @param result [Takagi::Message::Outbound, Hash, Object] The middleware result
    # @param logger [Logger, nil] Optional logger for debugging
    # @return [Takagi::Message::Outbound] The response message
    def self.build(inbound_request, result, logger: nil)
      case result
      when Takagi::Message::Outbound
        result
      when Hash
        logger&.debug("Returned #{result} as response")
        inbound_request.to_response('2.05 Content', result)
      else
        logger&.warn("Middleware returned non-Hash: #{result.inspect}")
        inbound_request.to_response('5.00 Internal Server Error', { error: 'Internal Server Error' })
      end
    end
  end
end
