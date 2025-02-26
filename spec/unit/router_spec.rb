# frozen_string_literal: true
require_relative '../../lib/takagi/router'

RSpec.describe Takagi::Router do
  before do
    class TestApp < Takagi::Router
      get "/ping" do
        { message: "Pong!" }
      end
    end
  end

  it "matches static routes" do
    route, _params = Takagi::Router.find_route("GET", "/ping")
    expect(route).not_to be_nil
    expect(route.call({})).to eq({ message: "Pong!" })
  end

  it "returns nil for unknown routes" do
    route, _params = Takagi::Router.find_route("GET", "/unknown")
    expect(route).to be_nil
  end
end
