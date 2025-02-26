# frozen_string_literal: true

module Takagi
  class Server
    def self.run!(port: 5683)
      server = UDPSocket.new
      server.bind("0.0.0.0", port)
      puts "Takagi running on CoAP://0.0.0.0:#{port}"

      loop do
        data, addr = server.recvfrom(1024)
        request = Message.parse(data)
        route, params = Router.find_route(request[:method], request[:path])

        response = if route
                     params.merge!(JSON.parse(request[:payload])) if request[:payload]
                     route.call(params)
                   else
                     { error: "Not Found" }
                   end

        response_data = Message.build_response(2.05, response, request[:token])
        server.send(response_data, 0, addr[3], addr[1])
      end
    end
  end
end
