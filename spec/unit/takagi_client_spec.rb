# frozen_string_literal: true

RSpec.describe Takagi::UdpClient do
  let(:server_uri) { 'coap://127.0.0.1:5683' }

  describe '#initialize' do
    it 'creates a client with retransmission enabled by default' do
      client = described_class.new(server_uri)
      expect(client.instance_variable_get(:@use_retransmission)).to be true
      expect(client.instance_variable_get(:@retransmission_manager)).to be_a(Takagi::Message::RetransmissionManager)
      client.close
    end

    it 'allows disabling retransmission' do
      client = described_class.new(server_uri, use_retransmission: false)
      expect(client.instance_variable_get(:@use_retransmission)).to be false
      expect(client.instance_variable_get(:@retransmission_manager)).to be_nil
      client.close
    end

    it 'starts the retransmission manager thread' do
      client = described_class.new(server_uri)
      manager = client.instance_variable_get(:@retransmission_manager)
      expect(manager.instance_variable_get(:@running)).to be true
      expect(manager.instance_variable_get(:@thread)).to be_alive
      client.close
    end
  end

  describe '#close' do
    it 'stops the retransmission manager' do
      client = described_class.new(server_uri)
      manager = client.instance_variable_get(:@retransmission_manager)

      client.close

      # Give the thread a moment to stop
      sleep 0.2

      expect(manager.instance_variable_get(:@running)).to be false
      expect(client.closed?).to be true
    end

    it 'is idempotent' do
      client = described_class.new(server_uri)

      expect { client.close }.not_to raise_error
      expect { client.close }.not_to raise_error

      expect(client.closed?).to be true
    end

    it 'works when retransmission is disabled' do
      client = described_class.new(server_uri, use_retransmission: false)

      expect { client.close }.not_to raise_error
      expect(client.closed?).to be true
    end
  end

  describe '.open' do
    it 'automatically closes the client after the block' do
      manager = nil

      described_class.open(server_uri) do |client|
        manager = client.instance_variable_get(:@retransmission_manager)
        expect(client.closed?).to be false
      end

      # Give the thread a moment to stop
      sleep 0.2

      expect(manager.instance_variable_get(:@running)).to be false
    end

    it 'closes the client even if an error occurs' do
      manager = nil

      expect do
        described_class.open(server_uri) do |client|
          manager = client.instance_variable_get(:@retransmission_manager)
          raise 'Test error'
        end
      end.to raise_error('Test error')

      # Give the thread a moment to stop
      sleep 0.2

      expect(manager.instance_variable_get(:@running)).to be false
    end

    it 'returns the block value' do
      result = described_class.open(server_uri) do |_client|
        'test value'
      end

      expect(result).to eq('test value')
    end

    it 'passes options to the client' do
      described_class.open(server_uri, timeout: 10, use_retransmission: false) do |client|
        expect(client.timeout).to eq(10)
        expect(client.instance_variable_get(:@use_retransmission)).to be false
      end
    end
  end

  describe '#closed?' do
    it 'returns false for a new client' do
      client = described_class.new(server_uri)
      expect(client.closed?).to be false
      client.close
    end

    it 'returns true after closing' do
      client = described_class.new(server_uri)
      client.close
      expect(client.closed?).to be true
    end
  end

  describe 'thread cleanup' do
    it 'prevents thread leaks when creating multiple clients' do
      initial_thread_count = Thread.list.size

      # Create and close multiple clients
      10.times do
        client = described_class.new(server_uri)
        client.close
      end

      # Give threads time to stop
      sleep 0.5

      # Should not have accumulated threads
      final_thread_count = Thread.list.size
      expect(final_thread_count).to be <= (initial_thread_count + 1) # Allow for small variance
    end

    it 'properly cleans up with the open pattern' do
      initial_thread_count = Thread.list.size

      # Create and auto-close multiple clients
      10.times do
        described_class.open(server_uri) do |_client|
          # Do nothing
        end
      end

      # Give threads time to stop
      sleep 0.5

      # Should not have accumulated threads
      final_thread_count = Thread.list.size
      expect(final_thread_count).to be <= (initial_thread_count + 1) # Allow for small variance
    end
  end
end
