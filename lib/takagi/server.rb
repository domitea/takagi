# frozen_string_literal: true

require_relative "logger"

module Takagi
  class Server
    LOGGER = Takagi::Logger

    def self.run!(port: 5683)
      server = UDPSocket.new
      server.bind("0.0.0.0", port)
      LOGGER.info("Takagi running on CoAP://0.0.0.0:#{port}")

      loop do
        data, addr = server.recvfrom(1024)
        request = Message.parse(data)

        LOGGER.info("Request: #{request[:method]} #{request[:path]}, Token: #{request[:token].unpack("H*").first}")

        route, params = Router.find_route(request[:method], request[:path])
        response = if route
                     params.merge!(JSON.parse(request[:payload])) if request[:payload]
                     route.call(params)
                   else
                     LOGGER.error("Route not found: #{request[:method]} #{request[:path]}")
                     { error: "Not Found" }
                   end

        response_data = Message.build_response(2.05, response, request[:token])
        LOGGER.info("Response: 2.05 Content -> #{response.to_json}")

        server.send(response_data, 0, addr[3], addr[1])
      end
    end
  end
end
