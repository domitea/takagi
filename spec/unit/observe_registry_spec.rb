# frozen_string_literal: true

RSpec.describe Takagi::ObserveRegistry do
  let(:subscriber) { { address: '127.0.0.1', port: 5683, token: 'abc' } }

  it "registers and unregisters subscribers" do
    described_class.subscribe('/foo', subscriber)
    expect(described_class.subscriptions['/foo']).to include(subscriber)

    described_class.unsubscribe('/foo', 'abc')
    expect(described_class.subscriptions['/foo']).to be_empty
  end

  it "notifies subscribers" do
    described_class.subscribe('/bar', subscriber)

    sender_double = instance_double(Takagi::Observer::Sender)
    allow(sender_double).to receive(:send_packet)
    allow(described_class).to receive(:sender).and_return(sender_double)

    described_class.notify('/bar', 42)

    expect(sender_double).to have_received(:send_packet).with(subscriber, 42)
  end
end