# frozen_string_literal: true

RSpec.describe Takagi::ObserveRegistry do
  let(:subscriber) { { address: '127.0.0.1', port: 5683, token: 'abc' } }

  before do
    described_class.subscriptions.clear
  end

  it "registers and unregisters subscribers" do
    described_class.subscribe('/foo', subscriber)
    stored = described_class.subscriptions['/foo'].first
    expect(stored).to include(subscriber)

    described_class.unsubscribe('/foo', 'abc')
    expect(described_class.subscriptions['/foo']).to be_empty
  end

  it "notifies subscribers" do
    described_class.subscribe('/bar', subscriber)

    sender_double = instance_double(Takagi::Observer::Sender)
    allow(sender_double).to receive(:send_packet)
    allow(described_class).to receive(:sender).and_return(sender_double)

    described_class.notify('/bar', 42)

    expect(sender_double).to have_received(:send_packet) do |entry, value|
      expect(entry).to include(subscriber)
      expect(value).to eq(42)
    end
  end

  describe '.cleanup_stale_observers' do
    it 'removes remote observers that exceeded max age' do
      described_class.subscribe('/stale', subscriber)
      entry = described_class.subscriptions['/stale'].first
      entry[:handler] = nil
      entry[:last_notified_at] = Time.now - 120

      cleaned = described_class.cleanup_stale_observers(max_age: 60)

      expect(cleaned).to eq(1)
      expect(described_class.subscriptions['/stale']).to be_nil
    end

    it 'keeps local handler subscriptions regardless of age' do
      described_class.subscribe('/local', subscriber.merge(handler: proc {}))
      entry = described_class.subscriptions['/local'].first
      entry[:last_notified_at] = Time.now - 1_000

      cleaned = described_class.cleanup_stale_observers(max_age: 60)

      expect(cleaned).to eq(0)
      expect(described_class.subscriptions['/local']).not_to be_empty
    end
  end
end
