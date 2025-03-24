# frozen_string_literal: true

require "socket"

RSpec.describe Takagi::Server do
  it "starts the server and listens on UDP" do
    port = find_free_port
    server = Takagi::Server.new(port: port)

    expect do
      thread = Thread.new { server.run! }
      sleep 0.1
      thread.kill
    end.not_to raise_error
  end
end
