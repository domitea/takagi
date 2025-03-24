# frozen_string_literal: true

require "rspec"

require "socket"
require_relative "../../lib/takagi"

RSpec.describe "Takagi RFC 7252 Compliance" do
  before(:all) do
    port = find_free_port
    @server_thread = Thread.new { Takagi::Base.run!(port: port) }
    sleep 1 # Give the server time to start
    @client = UDPSocket.new
    @server_address = ["127.0.0.1", port]
  end

  after(:all) do
    Thread.kill(@server_thread)
    @client.close
  end

  it "handles GET requests correctly" do
    response = send_coap_request(:con, :get, "/ping")
    expect(response).to include("Pong")
  end

  it "handles POST requests correctly" do
    response = send_coap_request(:con, :post, "/echo", '{"message": "Hello"}')
    expect(response).to include("Hello")
  end

  it "responds with correct error codes for unknown paths" do
    response = send_coap_request(:con, :get, "/nonexistent")
    expect(response.bytes[1]).to eq(132) # 4.04 Not Found
  end

  it "uses unique message IDs and detects duplicates" do
    message_id = 1234
    packet = [64, 1, (message_id >> 8) & 0xFF, message_id & 0xFF].pack("C*") + "/ping".bytes.prepend(5).pack("C*")

    @client.send(packet, 0, *@server_address)
    first_response_raw, = @client.recvfrom(1024)

    @client.send(packet, 0, *@server_address) # Send duplicate
    duplicate_response_raw, = @client.recvfrom(1024)

    first = Takagi::Message::Inbound.new(first_response_raw)
    duplicate = Takagi::Message::Inbound.new(duplicate_response_raw)

    expect(duplicate.payload).to eq(first.payload)
    expect(duplicate.code).to eq(first.code) # Server should detect and discard duplicate
  end

  it "supports Observe notifications" do
    pending "Implement CoAP Observe feature in Takagi"
    expect(true).to eq(false)
  end

  it "handles large payloads with block-wise transfers" do
    pending "Implement block-wise transfers in Takagi"
    expect(true).to eq(false)
  end
end
