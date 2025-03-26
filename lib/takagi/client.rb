# frozen_string_literal: true

require 'uri'
require 'optparse'
require 'socket'

module Takagi
  # Takagi Client: Client for communicating with the Takagi server over CoAP
  class Client
    attr_reader :server_uri, :timeout, :callbacks

    # Initializes the client
    # @param server_uri [String] URL of the Takagi server
    # @param timeout [Integer] Maximum time to wait for a response
    def initialize(server_uri, timeout: 5)
      @server_uri = URI(server_uri)
      @timeout = timeout
      @callbacks = {}
    end

    # Sends a GET request
    # @param path [String] Resource path
    # @param callback [Proc] (optional) Callback function for processing the response
    # Example CLI usage:
    # ./takagi-client -s coap://localhost:5683 -m get -p /status
    def get(path, &block)
      request(:get, path, nil, &block)
    end

    # Sends a POST request
    # @param path [String] Resource path
    # @param payload [String] Data to send
    # @param callback [Proc] (optional) Callback function for processing the response
    # Example CLI usage:
    # ./takagi-client -s coap://localhost:5683 -m post -p /data -d '{"value": 42}'
    def post(path, payload, &block)
      request(:post, path, payload, &block)
    end

    # Sends a PUT request
    # @param path [String] Resource path
    # @param payload [String] Data to send
    # @param callback [Proc] (optional) Callback function for processing the response
    # Example CLI usage:
    # ./takagi-client -s coap://localhost:5683 -m put -p /config -d '{"setting": "on"}'
    def put(path, payload, &block)
      request(:put, path, payload, &block)
    end

    # Sends a DELETE request
    # @param path [String] Resource path
    # @param callback [Proc] (optional) Callback function for processing the response
    # Example CLI usage:
    # ./takagi-client -s coap://localhost:5683 -m delete -p /obsolete
    def delete(path, &block)
      request(:delete, path, nil, &block)
    end

    private

    # Executes a request to the server using Takagi::Message::OutboundMessage
    # @param method [Symbol] HTTP method (:get, :post, :put, :delete)
    # @param path [String] Resource path
    # @param payload [String] (optional) Data for POST/PUT requests
    # @param callback [Proc] (optional) Callback function for processing the response
    def request(method, path, payload = nil, &callback)
      uri = URI.join(server_uri.to_s, path)
      message = Takagi::Message::OutboundMessage.new(method: method, uri: uri, payload: payload)

      begin
        socket = UDPSocket.new
        socket.send(message.encode, 0, uri.host, uri.port || 5683)
        response, = socket.recvfrom(1024)
        socket.close

        if callback
          callback.call(response)
        elsif @callbacks[:response]
          @callbacks[:response].call(response)
        else
          puts response
        end
      rescue StandardError => e
        puts "TakagiClient Error: #{e.message}"
      end
    end
  end
end
