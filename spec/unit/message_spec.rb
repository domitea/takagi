# frozen_string_literal: true

require "json"

RSpec.describe Takagi::Message do
  describe Takagi::Message::Inbound do
    let(:coap_get_packet) do
      # version=1, type=0, token_length=1, code=1 (GET), message_id=0x1234, token=0xAA
      # option delta=11 (Uri-Path), length=4, value="test"
      # payload="Ping"
      [
        0b01010001, 0x01, 0x12, 0x34, 0xAA,
        0xB4, "t".ord, "e".ord, "s".ord, "t".ord,
        0xFF, "P".ord, "i".ord, "n".ord, "g".ord
      ].pack("C*")
    end

    it "parses a CoAP GET request with payload and Uri-Path" do
      parsed = Takagi::Message::Inbound.new(coap_get_packet)

      expect(parsed.method).to eq("GET")
      expect(parsed.payload).to eq("Ping")
      expect(parsed.uri.to_s).to eq("coap://localhost/test")
    end

    it "parses empty payload correctly" do
      empty_payload_packet = [
        0b01010001, 0x01, 0x12, 0x34, 0xAA,
        0xB4, "t".ord, "e".ord, "s".ord, "t".ord
      ].pack("C*")

      parsed = Takagi::Message::Inbound.new(empty_payload_packet)
      expect(parsed.payload).to be_nil
    end
  end

  describe Takagi::Message::Outbound do
    it "builds a CoAP response with JSON payload" do
      message = Takagi::Message::Outbound.new(
        code: "2.05",
        payload: { message: "Pong" },
        token: "\xAA".b,
        message_id: 0x1234
      )

      packet = message.to_bytes

      expect(packet.bytesize).to be > 5
      expect(packet.force_encoding("ASCII-8BIT")).to include("\xFF".b) # payload marker
      expect(packet.force_encoding("ASCII-8BIT")).to include("Pong".b)
    end

    it "builds minimal CoAP response without payload" do
      message = Takagi::Message::Outbound.new(
        code: "2.05",
        payload: "",
        token: "\xBB".b,
        message_id: 0x4567
      )

      packet = message.to_bytes

      expect(packet.bytesize).to be > 4
      expect(packet.force_encoding("ASCII-8BIT")).not_to include("\xFF".b)
    end
  end
end
