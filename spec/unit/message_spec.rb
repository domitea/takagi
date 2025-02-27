# frozen_string_literal: true

require "json"
require_relative "../../lib/takagi/message"

RSpec.describe Takagi::Message do
  let(:coap_request) { [64, 1, 0, 1, 57, 112, 105, 110, 103].pack("C*") }

  it "parses a CoAP GET request" do
    parsed = Takagi::Message.parse(coap_request)
    expect(parsed[:method]).to eq("GET")
  end

  it "builds a CoAP response" do
    response = Takagi::Message.build_response(2.05, { message: "Pong" }, "".b)
    expect(response.bytesize).to be > 5
  end
end
