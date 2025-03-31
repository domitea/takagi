# frozen_string_literal: true

RSpec.describe Takagi::Observer::Watcher do
  let(:watcher) { described_class.new(interval: 0.1) }

  it "starts and stops the watcher" do
    thread = watcher.start
    expect(thread).to be_a(Thread)

    watcher.stop
    thread.join

    expect(thread.alive?).to be_falsey
  end

  it "calls notify during loop" do
    allow(Takagi::ObserveRegistry).to receive(:subscriptions).and_return({})
    allow(Takagi::ObserveRegistry).to receive(:notify)

    thread = watcher.start
    sleep 0.3

    watcher.stop
    thread.join

    expect(Takagi::ObserveRegistry).to have_received(:subscriptions).at_least(:once)
  end
end