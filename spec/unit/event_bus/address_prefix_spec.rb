# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Takagi::EventBus::AddressPrefix do
  # Clean up after each test
  after(:each) do
    described_class.clear!
    described_class.initialize_defaults!
  end

  describe '.register_distributed' do
    it 'registers a distributed prefix' do
      described_class.register_distributed('test.', 'Test Events')
      expect(described_class.distributed?('test.foo')).to be true
    end

    it 'stores metadata for prefix' do
      described_class.register_distributed('test.', 'Test Events', rfc: 'RFC 9999')
      metadata = described_class.metadata_for('test.')

      expect(metadata[:description]).to eq('Test Events')
      expect(metadata[:rfc]).to eq('RFC 9999')
      expect(metadata[:type]).to eq(:distributed)
    end
  end

  describe '.register_local' do
    it 'registers a local prefix' do
      described_class.register_local('test.', 'Test Events')
      expect(described_class.local?('test.foo')).to be true
    end

    it 'stores metadata for prefix' do
      described_class.register_local('test.', 'Test Events', rfc: 'RFC 8888')
      metadata = described_class.metadata_for('test.')

      expect(metadata[:description]).to eq('Test Events')
      expect(metadata[:rfc]).to eq('RFC 8888')
      expect(metadata[:type]).to eq(:local)
    end
  end

  describe '.distributed?' do
    it 'returns true for default distributed prefixes' do
      expect(described_class.distributed?('sensor.temp.room1')).to be true
      expect(described_class.distributed?('alert.fire.detected')).to be true
      expect(described_class.distributed?('cluster.node.health')).to be true
      expect(described_class.distributed?('reactor.state.changed')).to be true
      expect(described_class.distributed?('event.user.login')).to be true
    end

    it 'returns false for local prefixes' do
      expect(described_class.distributed?('system.startup')).to be false
      expect(described_class.distributed?('coap.message.sent')).to be false
      expect(described_class.distributed?('plugin.loaded')).to be false
    end

    it 'returns false for unknown prefixes' do
      expect(described_class.distributed?('unknown.event')).to be false
    end

    it 'returns true for custom distributed prefix' do
      described_class.register_distributed('custom.', 'Custom Events')
      expect(described_class.distributed?('custom.foo.bar')).to be true
    end
  end

  describe '.local?' do
    it 'returns true for default local prefixes' do
      expect(described_class.local?('system.startup')).to be true
      expect(described_class.local?('coap.message.sent')).to be true
      expect(described_class.local?('plugin.loaded')).to be true
    end

    it 'returns false for distributed prefixes' do
      expect(described_class.local?('sensor.temp')).to be false
      expect(described_class.local?('alert.fire')).to be false
    end

    it 'returns false for unknown prefixes' do
      expect(described_class.local?('unknown.event')).to be false
    end

    it 'returns true for custom local prefix' do
      described_class.register_local('custom.', 'Custom Events')
      expect(described_class.local?('custom.foo.bar')).to be true
    end
  end

  describe '.distributed_prefixes' do
    it 'returns all distributed prefixes' do
      prefixes = described_class.distributed_prefixes
      expect(prefixes.keys).to include('sensor.', 'alert.', 'cluster.', 'reactor.', 'event.')
    end

    it 'includes metadata for each prefix' do
      prefixes = described_class.distributed_prefixes
      expect(prefixes['sensor.'][:description]).to eq('Sensor Events')
      expect(prefixes['sensor.'][:rfc]).to eq('RFC 7641')
    end

    it 'returns a copy not the original' do
      prefixes = described_class.distributed_prefixes
      prefixes['test.'] = 'should not affect original'

      expect(described_class.distributed_prefixes.keys).not_to include('test.')
    end
  end

  describe '.local_prefixes' do
    it 'returns all local prefixes' do
      prefixes = described_class.local_prefixes
      expect(prefixes.keys).to include('system.', 'coap.', 'plugin.')
    end

    it 'includes metadata for each prefix' do
      prefixes = described_class.local_prefixes
      expect(prefixes['system.'][:description]).to eq('System Events')
      expect(prefixes['system.'][:type]).to eq(:local)
    end

    it 'returns a copy not the original' do
      prefixes = described_class.local_prefixes
      prefixes['test.'] = 'should not affect original'

      expect(described_class.local_prefixes.keys).not_to include('test.')
    end
  end

  describe '.all' do
    it 'returns all registered prefixes' do
      all_prefixes = described_class.all
      expect(all_prefixes.keys).to include('sensor.', 'system.', 'alert.', 'coap.')
    end

    it 'includes both distributed and local' do
      all_prefixes = described_class.all
      expect(all_prefixes.size).to be >= 8
    end
  end

  describe '.metadata_for' do
    it 'returns metadata for existing prefix' do
      metadata = described_class.metadata_for('sensor.')
      expect(metadata).not_to be_nil
      expect(metadata[:description]).to eq('Sensor Events')
    end

    it 'returns nil for non-existent prefix' do
      metadata = described_class.metadata_for('nonexistent.')
      expect(metadata).to be_nil
    end
  end

  describe '.unregister' do
    it 'removes a distributed prefix' do
      described_class.register_distributed('test.', 'Test')
      expect(described_class.distributed?('test.foo')).to be true

      described_class.unregister('test.')
      expect(described_class.distributed?('test.foo')).to be false
    end

    it 'removes a local prefix' do
      described_class.register_local('test.', 'Test')
      expect(described_class.local?('test.foo')).to be true

      described_class.unregister('test.')
      expect(described_class.local?('test.foo')).to be false
    end

    it 'returns truthy if prefix was registered' do
      described_class.register_distributed('test.', 'Test')
      result = described_class.unregister('test.')
      expect(result).to be_truthy
    end

    it 'returns falsy if prefix was not registered' do
      result = described_class.unregister('nonexistent.')
      expect(result).to be_falsy
    end
  end

  describe '.clear!' do
    it 'removes all registered prefixes' do
      expect(described_class.distributed?('sensor.temp')).to be true

      described_class.clear!

      expect(described_class.distributed?('sensor.temp')).to be false
      expect(described_class.local?('system.startup')).to be false
      expect(described_class.all).to be_empty
    end
  end

  describe '.initialize_defaults!' do
    it 'registers default distributed prefixes' do
      described_class.clear!
      expect(described_class.distributed?('sensor.temp')).to be false

      described_class.initialize_defaults!

      expect(described_class.distributed?('sensor.temp')).to be true
      expect(described_class.distributed?('alert.fire')).to be true
      expect(described_class.distributed?('cluster.node')).to be true
      expect(described_class.distributed?('reactor.state')).to be true
      expect(described_class.distributed?('event.user')).to be true
    end

    it 'registers default local prefixes' do
      described_class.clear!
      expect(described_class.local?('system.startup')).to be false

      described_class.initialize_defaults!

      expect(described_class.local?('system.startup')).to be true
      expect(described_class.local?('coap.message')).to be true
      expect(described_class.local?('plugin.loaded')).to be true
    end
  end

  describe 'thread safety' do
    it 'handles concurrent registrations' do
      threads = 10.times.map do |i|
        Thread.new do
          described_class.register_distributed("thread#{i}.", "Thread #{i}")
        end
      end

      threads.each(&:join)

      10.times do |i|
        expect(described_class.distributed?("thread#{i}.foo")).to be true
      end
    end

    it 'handles concurrent reads' do
      errors = []

      threads = 20.times.map do
        Thread.new do
          begin
            100.times do
              described_class.distributed?('sensor.temp')
              described_class.local?('system.startup')
              described_class.all
            end
          rescue => e
            errors << e
          end
        end
      end

      threads.each(&:join)
      expect(errors).to be_empty
    end

    it 'handles concurrent reads and writes' do
      stop = false
      errors = []

      writer = Thread.new do
        i = 0
        while !stop
          begin
            described_class.register_distributed("dynamic#{i}.", "Dynamic #{i}")
            i += 1
          rescue => e
            errors << e
          end
        end
      end

      readers = 5.times.map do
        Thread.new do
          100.times do
            begin
              described_class.distributed?('sensor.temp')
              described_class.all
            rescue => e
              errors << e
            end
          end
        end
      end

      readers.each(&:join)
      stop = true
      writer.join

      expect(errors).to be_empty
    end
  end

  describe 'extensibility' do
    it 'allows plugins to register custom distributed prefixes' do
      described_class.register_distributed('custom.plugin.', 'Custom Plugin Events')

      expect(described_class.distributed?('custom.plugin.action.executed')).to be true
      expect(described_class.metadata_for('custom.plugin.')[:description]).to eq('Custom Plugin Events')
    end

    it 'allows plugins to register custom local prefixes' do
      described_class.register_local('internal.cache.', 'Internal Cache Events')

      expect(described_class.local?('internal.cache.hit')).to be true
      expect(described_class.local?('internal.cache.miss')).to be true
    end
  end
end