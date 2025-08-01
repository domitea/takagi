# frozen_string_literal: true

require "socket"

RSpec.describe Takagi::Server::Udp do
  it "starts and shuts down cleanly" do
    port = find_free_port
    server = Takagi::Server::Udp.new(port: port)

    thread = Thread.new { server.run! }
    sleep 0.1
  ensure
    server.shutdown!
    thread&.join
  end
end
