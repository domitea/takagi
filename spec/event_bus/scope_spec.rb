# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Takagi::EventBus::Scope do
  describe '.valid?' do
    it 'returns true for LOCAL' do
      expect(described_class.valid?(:local)).to be true
    end

    it 'returns true for CLUSTER' do
      expect(described_class.valid?(:cluster)).to be true
    end

    it 'returns true for GLOBAL' do
      expect(described_class.valid?(:global)).to be true
    end

    it 'returns false for invalid scope' do
      expect(described_class.valid?(:invalid)).to be false
      expect(described_class.valid?(:foo)).to be false
      expect(described_class.valid?(nil)).to be false
    end
  end

  describe '.normalize' do
    it 'returns LOCAL for nil' do
      expect(described_class.normalize(nil)).to eq(:local)
    end

    it 'returns scope as-is if valid' do
      expect(described_class.normalize(:local)).to eq(:local)
      expect(described_class.normalize(:cluster)).to eq(:cluster)
      expect(described_class.normalize(:global)).to eq(:global)
    end

    it 'converts string to symbol' do
      expect(described_class.normalize('local')).to eq(:local)
      expect(described_class.normalize('cluster')).to eq(:cluster)
      expect(described_class.normalize('global')).to eq(:global)
    end

    it 'returns LOCAL for invalid scope' do
      expect(described_class.normalize(:invalid)).to eq(:local)
      expect(described_class.normalize('foo')).to eq(:local)
    end
  end

  describe '.distributed?' do
    it 'returns true for CLUSTER' do
      expect(described_class.distributed?(:cluster)).to be true
    end

    it 'returns true for GLOBAL' do
      expect(described_class.distributed?(:global)).to be true
    end

    it 'returns false for LOCAL' do
      expect(described_class.distributed?(:local)).to be false
    end
  end

  describe '.external?' do
    it 'returns true for GLOBAL' do
      expect(described_class.external?(:global)).to be true
    end

    it 'returns false for CLUSTER' do
      expect(described_class.external?(:cluster)).to be false
    end

    it 'returns false for LOCAL' do
      expect(described_class.external?(:local)).to be false
    end
  end

  describe '.local_only?' do
    it 'returns true for LOCAL' do
      expect(described_class.local_only?(:local)).to be true
    end

    it 'returns false for CLUSTER' do
      expect(described_class.local_only?(:cluster)).to be false
    end

    it 'returns false for GLOBAL' do
      expect(described_class.local_only?(:global)).to be false
    end
  end

  describe 'constants' do
    it 'defines LOCAL' do
      expect(described_class::LOCAL).to eq(:local)
    end

    it 'defines CLUSTER' do
      expect(described_class::CLUSTER).to eq(:cluster)
    end

    it 'defines GLOBAL' do
      expect(described_class::GLOBAL).to eq(:global)
    end

    it 'defines DEFAULT as LOCAL' do
      expect(described_class::DEFAULT).to eq(:local)
    end

    it 'defines ALL' do
      expect(described_class::ALL).to eq([:local, :cluster, :global])
    end
  end
end
