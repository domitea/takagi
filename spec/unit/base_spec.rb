# frozen_string_literal: true

RSpec.describe Takagi::Base do
  let(:app) do
    Class.new(Takagi::Base) do
      get "/ping" do
        { message: "Pong!" }
      end
    end
  end

  it "matches static routes" do
    route, _params = app.router.find_route("GET", "/ping")
    expect(route).not_to be_nil
    expect(route.call({})).to eq({ message: "Pong!" })
  end

  it "returns nil for unknown routes" do
    route, _params = app.router.find_route("GET", "/unknown")
    expect(route).to be_nil
  end
end
