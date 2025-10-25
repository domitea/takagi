# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Takagi::EventBus::RactorPool do
  describe '#initialize' do
    it 'creates a pool with default size' do
      pool = described_class.new
      expect(pool.size).to eq(10)
      pool.shutdown
    end

    it 'creates a pool with custom size' do
      pool = described_class.new(5)
      expect(pool.size).to eq(5)
      pool.shutdown
    end

    it 'initializes workers' do
      pool = described_class.new(3)
      expect(pool).to be_running
      pool.shutdown
    end
  end

  describe '#post' do
    it 'executes work in a worker' do
      pool = described_class.new(2)
      result = []
      mutex = Mutex.new

      pool.post do
        mutex.synchronize { result << 'executed' }
      end

      # Give worker time to execute
      sleep 0.1
      expect(result).to eq(['executed'])
      pool.shutdown
    end

    it 'executes multiple tasks' do
      pool = described_class.new(3)
      results = []
      mutex = Mutex.new

      10.times do |i|
        pool.post do
          mutex.synchronize { results << i }
        end
      end

      # Wait for all tasks to complete
      sleep 0.2
      expect(results.size).to eq(10)
      expect(results.sort).to eq((0..9).to_a)
      pool.shutdown
    end

    it 'handles errors without killing worker' do
      pool = described_class.new(2)
      results = []
      mutex = Mutex.new

      # Post task that raises error
      pool.post { raise 'Test error' }

      # Post task that succeeds
      pool.post do
        mutex.synchronize { results << 'success' }
      end

      sleep 0.1
      expect(results).to eq(['success'])
      pool.shutdown
    end

    it 'raises error when pool is shutdown' do
      pool = described_class.new(2)
      pool.shutdown

      expect { pool.post { 'work' } }.to raise_error('Pool is shutdown')
    end
  end

  describe '#shutdown' do
    it 'stops the pool gracefully' do
      pool = described_class.new(3)
      expect(pool).to be_running

      pool.shutdown
      expect(pool).not_to be_running
    end

    it 'waits for current work to complete' do
      pool = described_class.new(2)
      results = []
      mutex = Mutex.new

      pool.post do
        sleep 0.05
        mutex.synchronize { results << 'completed' }
      end

      pool.shutdown
      expect(results).to eq(['completed'])
    end

    it 'is idempotent' do
      pool = described_class.new(2)
      pool.shutdown
      expect { pool.shutdown }.not_to raise_error
    end
  end

  describe '#running?' do
    it 'returns true when pool is running' do
      pool = described_class.new(2)
      expect(pool.running?).to be true
      pool.shutdown
    end

    it 'returns false when pool is shutdown' do
      pool = described_class.new(2)
      pool.shutdown
      expect(pool.running?).to be false
    end
  end

  describe 'concurrency' do
    it 'handles high concurrency' do
      pool = described_class.new(10)
      results = []
      mutex = Mutex.new
      count = 100

      count.times do |i|
        pool.post do
          mutex.synchronize { results << i }
        end
      end

      # Wait for all tasks
      sleep 0.5
      expect(results.size).to eq(count)
      pool.shutdown
    end

    it 'distributes work across workers' do
      pool = described_class.new(5)
      worker_names = []
      mutex = Mutex.new

      50.times do
        pool.post do
          # Add small delay to ensure work is distributed
          sleep 0.01
          mutex.synchronize { worker_names << Thread.current.name }
        end
      end

      # Wait for all tasks to complete
      sleep 1.0
      # Should have used multiple workers
      expect(worker_names.uniq.size).to be >= 2
      pool.shutdown
    end
  end

  describe 'error handling' do
    it 'recovers from errors and continues processing' do
      pool = described_class.new(3)
      results = []
      mutex = Mutex.new

      # Mix of failing and successful tasks
      5.times do |i|
        pool.post do
          raise 'Error' if i.even?
          mutex.synchronize { results << i }
        end
      end

      sleep 0.2
      # Odd numbers should succeed
      expect(results.sort).to eq([1, 3])
      pool.shutdown
    end
  end
end