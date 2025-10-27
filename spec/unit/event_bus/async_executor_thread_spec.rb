# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Takagi::EventBus::AsyncExecutor::ThreadExecutor do
  let(:handler) { proc { |msg| results << msg } }
  let(:results) { [] }

  describe '#initialize' do
    it 'creates a pool with default size' do
      executor = described_class.new(size: 0)
      expect(executor.size).to eq(1)
      executor.shutdown
    end

    it 'creates a pool with custom size' do
      executor = described_class.new(size: 5)
      expect(executor.size).to eq(5)
      executor.shutdown
    end
  end

  describe '#post' do
    it 'executes work in a worker thread' do
      executor = described_class.new(size: 2)
      executor.post(handler, 'executed')
      sleep 0.05
      executor.shutdown
      expect(results).to eq(['executed'])
    end

    it 'handles multiple tasks' do
      executor = described_class.new(size: 3)
      10.times { |i| executor.post(handler, i) }
      sleep 0.2
      executor.shutdown
      expect(results.sort).to eq((0..9).to_a)
    end

    it 'keeps running after an exception' do
      executor = described_class.new(size: 2)
      executor.post(proc { |_msg| raise 'boom' }, nil)
      executor.post(handler, 'success')
      sleep 0.1
      executor.shutdown
      expect(results).to eq(['success'])
    end

    it 'raises when executor is shutdown' do
      executor = described_class.new(size: 1)
      executor.shutdown
      expect { executor.post(handler, 'work') }.to raise_error('Executor is shutdown')
    end
  end

  describe '#shutdown' do
    it 'stops workers gracefully' do
      executor = described_class.new(size: 2)
      expect(executor.running?).to be true
      executor.shutdown
      expect(executor.running?).to be false
    end

    it 'waits for current jobs' do
      executor = described_class.new(size: 1)
      executor.post(proc { |_msg| sleep 0.05; results << 'done' }, nil)
      executor.shutdown
      expect(results).to eq(['done'])
    end

    it 'is idempotent' do
      executor = described_class.new(size: 1)
      executor.shutdown
      expect { executor.shutdown }.not_to raise_error
    end
  end

  describe 'concurrency' do
    it 'processes many tasks' do
      executor = described_class.new(size: 5)
      100.times { |i| executor.post(handler, i) }
      sleep 0.5
      executor.shutdown
      expect(results.size).to eq(100)
    end
  end
end
