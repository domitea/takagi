# frozen_string_literal: true

require 'tempfile'

RSpec.describe Takagi::Config do
  let(:config) { described_class.new }
  let(:tmpfile) { Tempfile.new('takagi-config') }

  after do
    tmpfile.close!
  end

  def write_config(contents)
    tmpfile.rewind
    tmpfile.write(contents)
    tmpfile.flush
    config.load_file(tmpfile.path)
  end

  describe '#load_file' do
    it 'prefers the processes key over the legacy process key' do
      write_config <<~YAML
        processes: 4
        process: 1
      YAML

      expect(config.processes).to eq(4)
    end

    it 'falls back to legacy process key when processes is absent' do
      write_config <<~YAML
        process: 3
      YAML

      expect(config.processes).to eq(3)
    end

    it 'rejects unsafe YAML objects' do
      tmpfile.rewind
      tmpfile.write("foo: !ruby/object:Object {}\n")
      tmpfile.flush

      expect { config.load_file(tmpfile.path) }.to raise_error(Psych::DisallowedClass)
    end
  end

  describe 'logger configuration' do
    it 'applies logger level and output settings' do
      write_config <<~YAML
        logger:
          level: warn
          output: stdout
      YAML

      logger = config.logger
      internal_logger = logger.instance_variable_get(:@logger)
      expect(logger).to be_a(Takagi::Logger)
      expect(internal_logger.level).to eq(::Logger::WARN)
    end
  end
end
