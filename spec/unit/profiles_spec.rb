# frozen_string_literal: true

RSpec.describe Takagi::Profiles do
  describe '.get' do
    it 'returns a profile by name' do
      profile = described_class.get(:high_throughput)
      expect(profile[:processes]).to eq(8)
      expect(profile[:threads]).to eq(4)
    end

    it 'returns nil for unknown profile' do
      expect(described_class.get(:unknown)).to be_nil
    end

    it 'returns a copy to prevent modification' do
      profile1 = described_class.get(:minimal)
      profile2 = described_class.get(:minimal)

      profile1[:processes] = 999

      expect(profile2[:processes]).to eq(1) # Not modified
    end
  end

  describe '.exists?' do
    it 'returns true for existing profile' do
      expect(described_class.exists?(:high_throughput)).to be true
    end

    it 'returns false for unknown profile' do
      expect(described_class.exists?(:unknown)).to be false
    end
  end

  describe '.available' do
    it 'returns all profile names' do
      names = described_class.available
      expect(names).to include(:minimal, :low_traffic, :long_lived, :high_throughput, :large_payloads, :custom)
    end
  end

  describe '.summary' do
    it 'returns human-readable summary' do
      summary = described_class.summary
      expect(summary).to include('Available Load Profiles')
      expect(summary).to include('high_throughput')
      expect(summary).to include('Processes: 8')
    end
  end

  describe '.validate!' do
    it 'validates known profiles' do
      expect { described_class.validate!(:high_throughput) }.not_to raise_error
    end

    it 'raises error for unknown profile' do
      expect { described_class.validate!(:unknown) }.to raise_error(ArgumentError, /Unknown profile/)
    end

    it 'raises error for custom profile without processes' do
      config = { threads: 2 }
      expect do
        described_class.validate!(:custom, config)
      end.to raise_error(ArgumentError, /requires :processes/)
    end

    it 'raises error for custom profile without threads' do
      config = { processes: 2 }
      expect do
        described_class.validate!(:custom, config)
      end.to raise_error(ArgumentError, /requires :threads/)
    end

    it 'raises error for processes < 1' do
      config = { processes: 0, threads: 2 }
      expect do
        described_class.validate!(:custom, config)
      end.to raise_error(ArgumentError, /Processes must be >= 1/)
    end

    it 'raises error for threads < 1' do
      config = { processes: 2, threads: 0 }
      expect do
        described_class.validate!(:custom, config)
      end.to raise_error(ArgumentError, /Threads must be >= 1/)
    end
  end

  describe '.apply' do
    it 'applies profile configuration' do
      config = described_class.apply(:high_throughput)
      expect(config[:processes]).to eq(8)
      expect(config[:threads]).to eq(4)
    end

    it 'applies profile with overrides' do
      config = described_class.apply(:high_throughput, processes: 16)
      expect(config[:processes]).to eq(16)
      expect(config[:threads]).to eq(4)
    end

    it 'raises error for unknown profile' do
      expect { described_class.apply(:unknown) }.to raise_error(ArgumentError, /Unknown profile/)
    end

    it 'validates overrides' do
      expect do
        described_class.apply(:high_throughput, processes: 0)
      end.to raise_error(ArgumentError, /Processes must be >= 1/)
    end
  end

  describe 'profile definitions' do
    it 'defines minimal profile' do
      profile = described_class.get(:minimal)
      expect(profile[:processes]).to eq(1)
      expect(profile[:threads]).to eq(1)
    end

    it 'defines low_traffic profile' do
      profile = described_class.get(:low_traffic)
      expect(profile[:processes]).to eq(1)
      expect(profile[:threads]).to eq(2)
    end

    it 'defines long_lived profile' do
      profile = described_class.get(:long_lived)
      expect(profile[:processes]).to eq(2)
      expect(profile[:threads]).to eq(8)
    end

    it 'defines high_throughput profile' do
      profile = described_class.get(:high_throughput)
      expect(profile[:processes]).to eq(8)
      expect(profile[:threads]).to eq(4)
    end

    it 'defines large_payloads profile' do
      profile = described_class.get(:large_payloads)
      expect(profile[:processes]).to eq(2)
      expect(profile[:threads]).to eq(2)
      expect(profile[:buffer_size]).to eq(10 * 1024 * 1024)
    end

    it 'defines custom profile' do
      profile = described_class.get(:custom)
      expect(profile[:processes]).to be_nil
      expect(profile[:threads]).to be_nil
    end
  end
end
