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

  it "responds to empty confirmable with ACK" do
    message_id = rand(0..0xFFFF)
    packet = [0x40, 0x00, (message_id >> 8), message_id & 0xFF].pack("C*") # Ver:1, Type:CON, TokenLen:0, Code:0.00

    @client.send(packet, 0, *@server_address)
    response = @client.recvfrom(1024).first

    header = response.bytes
    type = (header[0] >> 4) & 0b11
    version = (header[0] >> 6) & 0b11

    expect(version).to eq(1)              # CoAP version
    expect(type).to eq(2)                 # ACK
    expect(header[1]).to eq(0)            # Code: 0.00 Empty Message
    expect((header[2] << 8) | header[3]).to eq(message_id) # Same message ID
  end

  it "responds with RST when receiving unexpected NON message" do
    message_id = rand(0..0xFFFF)
    # NON (Type: 1), Code: 0.00 (Empty)
    packet = [0x50, 0x00, (message_id >> 8), message_id & 0xFF].pack("C*")

    @client.send(packet, 0, *@server_address)
    response = @client.recvfrom(1024).first
    header = response.bytes

    version = (header[0] >> 6) & 0b11
    type = (header[0] >> 4) & 0b11

    expect(version).to eq(1)
    expect(type).to eq(3) # RST
    expect(header[1]).to eq(0) # Empty code
    expect((header[2] << 8) | header[3]).to eq(message_id)
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
