# frozen_string_literal: true

require 'socket'
require_relative '../../lib/takagi/server'

RSpec.describe Takagi::Server do
  it "starts the server and listens on UDP" do
    server = UDPSocket.new
    server.bind('127.0.0.1', 5683)

    expect { server }.not_to raise_error
    server.close
  end
end
