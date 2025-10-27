# frozen_string_literal: true

require 'spec_helper'
require 'timeout'

RSpec.describe Takagi::EventBus::AsyncExecutor::ProcessExecutor do
  describe '#post' do
    it 'executes work in a child process' do
      reader, writer = IO.pipe
      writer.sync = true
      handler = Takagi::EventBus::Handler.new('spec.process') do |msg|
        writer.puts(msg)
      end
      store = Takagi::EventBus.instance_variable_get(:@handler_store)
      store[handler.pool_id] = handler

      executor = described_class.new(processes: 1, threads: 1)
      executor.post(handler, 'payload')

      line = Timeout.timeout(1) { reader.gets&.strip }

      executor.shutdown
      reader.close
      writer.close
      store.delete(handler.pool_id)

      expect(line).to eq('payload')
    end

    it 'falls back to inline execution when processes are zero' do
      handler = double('handler')
      expect(handler).to receive(:call).with('message')

      executor = described_class.new(processes: 0, threads: 1)
      executor.post(handler, 'message')
      executor.shutdown
    end
  end

  describe '#register_handler' do
    it 'marks restart so new handlers are visible' do
      reader, writer = IO.pipe
      handler = Takagi::EventBus::Handler.new('spec.process') { |msg| writer.puts(msg) }
      store = Takagi::EventBus.instance_variable_get(:@handler_store)
      store[handler.pool_id] = handler

      executor = described_class.new(processes: 1, threads: 1)
      writer.sync = true
      executor.register_handler(handler)
      executor.post(handler, 'initial')
      first = Timeout.timeout(1) { reader.gets&.strip }

      executor.register_handler(handler)
      executor.post(handler, 'restart')
      second = Timeout.timeout(1) { reader.gets&.strip }
      expect(first).to eq('initial')
      expect(second).to eq('restart')

      executor.shutdown
      reader.close
      writer.close
      store.delete(handler.pool_id)
    end
  end
end
