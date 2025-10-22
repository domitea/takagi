# frozen_string_literal: true

require 'uri'
require 'optparse'
require 'socket'
require_relative 'message/retransmission_manager'

module Takagi
  # Takagi Client: Client for communicating with the Takagi server over CoAP
  class Client
    attr_reader :server_uri, :timeout, :callbacks

    # Initializes the client
    # @param server_uri [String] URL of the Takagi server
    # @param timeout [Integer] Maximum time to wait for a response
    # @param use_retransmission [Boolean] Enable RFC 7252 §4.2 compliant retransmission (default: true)
    def initialize(server_uri, timeout: 5, use_retransmission: true)
      @server_uri = URI(server_uri)
      @timeout = timeout
      @callbacks = {}
      @use_retransmission = use_retransmission

      return unless @use_retransmission

      @retransmission_manager = Takagi::Message::RetransmissionManager.new
      @retransmission_manager.start
    end

    # Registers a callback for a given event
    # @param event [Symbol] Event name (e.g., :response)
    # @param callback [Proc] Callback function to handle the event
    def on(event, &callback)
      @callbacks[event] = callback
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

    # Executes a request to the server using Takagi::Message::Request
    # @param method [Symbol] HTTP method (:get, :post, :put, :delete)
    # @param path [String] Resource path
    # @param payload [String] (optional) Data for POST/PUT requests
    # @param callback [Proc] (optional) Callback function for processing the response
    def request(method, path, payload = nil, &callback)
      uri = URI.join(server_uri.to_s, path)
      message = Takagi::Message::Request.new(method: method, uri: uri, payload: payload)

      if @use_retransmission
        request_with_retransmission(message, uri, &callback)
      else
        request_simple(message, uri, &callback)
      end
    end

    # Simple request without retransmission (legacy mode)
    def request_simple(message, uri, &callback)
      socket = UDPSocket.new
      socket.send(message.to_bytes, 0, uri.host, uri.port || 5683)
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

    # RFC 7252 §4.2 compliant request with automatic retransmission
    def request_with_retransmission(message, uri, &callback)
      socket = UDPSocket.new
      state = send_with_retransmission(message, socket, uri)
      socket.close
      handle_response_state(state, &callback)
    rescue StandardError => e
      puts "TakagiClient Error: #{e.message}"
    end

    def send_with_retransmission(message, socket, uri)
      state = { response_received: false, response_data: nil, error: nil }

      @retransmission_manager.send_confirmable(
        message.message_id, message.to_bytes, socket, uri.host, uri.port || 5683
      ) { |resp, err| update_state(state, resp, err) }

      wait_for_response(message, socket, state)
      state
    end

    def wait_for_response(message, socket, state)
      start_time = Time.now
      check_socket_for_response(message, socket, state) until state[:response_received] || (Time.now - start_time) > @timeout
    end

    def check_socket_for_response(message, socket, state)
      return unless socket.wait_readable(0.1)

      state[:response_data], = socket.recvfrom(1024)
      @retransmission_manager.handle_response(message.message_id, state[:response_data])
      state[:response_received] = true
    rescue StandardError => e
      update_state(state, nil, e.message)
    end

    def update_state(state, response_data, error)
      state[:response_data] = response_data
      state[:error] = error
      state[:response_received] = true
    end

    def handle_response_state(state, &callback)
      if state[:response_received] && !state[:error]
        deliver_response(state[:response_data], &callback)
      elsif state[:error]
        puts "TakagiClient Error: #{state[:error]}"
      else
        puts 'TakagiClient Error: Request timeout'
      end
    end

    def deliver_response(response_data, &callback)
      return callback.call(response_data) if callback
      return @callbacks[:response].call(response_data) if @callbacks[:response]

      puts response_data
    end
  end
end
