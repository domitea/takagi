# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Takagi::CBOR::Decoder do
  describe '.decode' do
    it 'decodes small unsigned integers (0-23)' do
      expect(described_class.decode("\x00")).to eq(0)
      expect(described_class.decode("\x0A")).to eq(10)
      expect(described_class.decode("\x17")).to eq(23)
    end

    it 'decodes uint8 (24-255)' do
      expect(described_class.decode("\x18\x18")).to eq(24)
      expect(described_class.decode("\x18d")).to eq(100)
      expect(described_class.decode("\x18\xFF")).to eq(255)
    end

    it 'decodes uint16 (256-65535)' do
      expect(described_class.decode("\x19\x01\x00")).to eq(256)
      expect(described_class.decode("\x19\x03\xE8")).to eq(1000)
      expect(described_class.decode("\x19\xFF\xFF")).to eq(65535)
    end

    it 'decodes uint32' do
      expect(described_class.decode("\x1A\x00\x01\x00\x00")).to eq(65536)
      expect(described_class.decode("\x1A\x00\x0F\x42\x40")).to eq(1_000_000)
    end

    it 'decodes uint64' do
      expect(described_class.decode("\x1B\x00\x00\x00\x01\x00\x00\x00\x00")).to eq(4_294_967_296)
    end

    it 'decodes negative integers' do
      expect(described_class.decode("\x20")).to eq(-1)
      expect(described_class.decode("\x29")).to eq(-10)
      expect(described_class.decode("\x38\x63")).to eq(-100)
      expect(described_class.decode("\x39\x03\xE7")).to eq(-1000)
    end

    it 'decodes UTF-8 strings' do
      expect(described_class.decode("\x60")).to eq('')
      expect(described_class.decode("\x61a")).to eq('a')
      expect(described_class.decode("\x64IETF")).to eq('IETF')
      expect(described_class.decode("\x6Bhello world")).to eq('hello world')
    end

    it 'decodes UTF-8 multibyte characters' do
      result = described_class.decode("\x62\xC3\xA4") # "ä" in UTF-8
      expect(result).to eq('ä')
      expect(result.encoding).to eq(Encoding::UTF-8)
    end

    it 'raises DecodeError for invalid UTF-8' do
      # Invalid UTF-8 sequence
      expect { described_class.decode("\x62\xFF\xFE") }.to raise_error(Takagi::CBOR::DecodeError, /Invalid UTF-8/)
    end

    it 'decodes arrays' do
      expect(described_class.decode("\x80")).to eq([])
      expect(described_class.decode("\x83\x01\x02\x03")).to eq([1, 2, 3])
      expect(described_class.decode("\x83\x01\x82\x02\x03\x82\x04\x05")).to eq([1, [2, 3], [4, 5]])
    end

    it 'decodes hashes (maps)' do
      expect(described_class.decode("\xA0")).to eq({})
      expect(described_class.decode("\xA1\x61a\x01")).to eq({ 'a' => 1 })
      expect(described_class.decode("\xA2\x61a\x01\x61b\x02")).to eq({ 'a' => 1, 'b' => 2 })
    end

    it 'decodes booleans' do
      expect(described_class.decode("\xF4")).to eq(false)
      expect(described_class.decode("\xF5")).to eq(true)
    end

    it 'decodes nil' do
      expect(described_class.decode("\xF6")).to be_nil
    end

    it 'decodes 64-bit floats (IEEE 754 double precision)' do
      # 1.5 encoded as float64
      result = described_class.decode("\xFB\x3F\xF8\x00\x00\x00\x00\x00\x00")
      expect(result).to be_within(0.0001).of(1.5)
    end

    it 'decodes 32-bit floats (IEEE 754 single precision)' do
      # 1.5 encoded as float32
      result = described_class.decode("\xFA\x3F\xC0\x00\x00")
      expect(result).to be_within(0.0001).of(1.5)
    end

    it 'decodes 16-bit floats (IEEE 754 half precision)' do
      # Test positive number
      result = described_class.decode("\xF9\x3C\x00") # 1.0 in float16
      expect(result).to be_within(0.01).of(1.0)
    end

    it 'decodes Time from epoch timestamp (tag 1)' do
      # Tag 1 with integer 1363896240
      result = described_class.decode("\xC1\x1A\x51\x4B\x67\xB0")
      expect(result).to be_a(Time)
      expect(result.to_i).to eq(1_363_896_240)
    end

    it 'decodes complex nested structures' do
      # {"name": "sensor", "value": 25, "tags": ["temp", "room1"]}
      cbor = "\xA3\x64name\x66sensor\x65value\x18\x19\x64tags\x82\x64temp\x65room1"
      result = described_class.decode(cbor)
      expect(result).to be_a(Hash)
      expect(result['name']).to eq('sensor')
      expect(result['value']).to eq(25)
      expect(result['tags']).to eq(['temp', 'room1'])
    end

    it 'handles roundtrip decoding/encoding' do
      cbor = "\xA2\x61a\x01\x61b\x82\x02\x03"
      decoded = described_class.decode(cbor)
      encoded = Takagi::CBOR::Encoder.encode(decoded)
      redecoded = described_class.decode(encoded)
      expect(redecoded).to eq(decoded)
    end

    it 'raises DecodeError for truncated data' do
      # uint16 marker but only 1 byte of data
      expect { described_class.decode("\x19\x01") }.to raise_error(Takagi::CBOR::DecodeError, /Unexpected end of input/)
    end

    it 'raises DecodeError for empty input' do
      expect { described_class.decode('') }.to raise_error(Takagi::CBOR::DecodeError, /Unexpected end of input/)
    end

    it 'raises DecodeError for reserved additional info values' do
      # Additional info 28 is reserved
      expect { described_class.decode("\x1C") }.to raise_error(Takagi::CBOR::DecodeError, /Reserved/)
    end

    it 'raises UnsupportedError for indefinite-length items' do
      # Indefinite-length array marker (additional info 31)
      expect { described_class.decode("\x9F") }.to raise_error(Takagi::CBOR::UnsupportedError, /Indefinite-length/)
    end

    it 'prevents stack overflow with max nesting depth' do
      # Create deeply nested array
      deeply_nested = "\x81" * 101 # 101 levels deep
      deeply_nested += "\x00" # End with integer 0

      expect {
        described_class.decode(deeply_nested)
      }.to raise_error(Takagi::CBOR::DecodeError, /Maximum nesting depth/)
    end

    it 'prevents memory exhaustion with max collection size' do
      # Array with size claiming to be 100,001 elements
      oversized = "\x1A\x00\x01\x86\xA1" # Major type 4, uint32 = 100,001
      oversized = "\x80" + oversized[1..-1] # Fix to be valid array marker

      # Actually, let's use proper encoding for large array
      oversized = [0b100_11010].pack('C') # Array with 4-byte length
      oversized += [100_001].pack('N') # Size: 100,001

      expect {
        described_class.decode(oversized)
      }.to raise_error(Takagi::CBOR::DecodeError, /Collection size.*exceeds maximum/)
    end

    it 'ignores unknown tags gracefully' do
      # Tag 999 (unknown) with integer value 42
      result = described_class.decode("\xD9\x03\xE7\x18\x2A")
      # Should decode the value, ignoring the unknown tag
      expect(result).to eq(42)
    end

    it 'converts symbol keys to strings' do
      # This test assumes encoder converts symbols to strings
      original = { temp: 25, humidity: 60 }
      encoded = Takagi::CBOR::Encoder.encode(original)
      decoded = described_class.decode(encoded)
      expect(decoded.keys).to all(be_a(String))
    end

    it 'handles byte strings (binary data)' do
      # Byte string of length 4
      binary_data = "\x44\x01\x02\x03\x04"
      result = described_class.decode(binary_data)
      expect(result).to eq("\x01\x02\x03\x04")
      expect(result.encoding).to eq(Encoding::BINARY)
    end

    it 'handles large strings correctly' do
      # String of length 256 (requires uint16 encoding)
      long_string = 'a' * 256
      encoded = Takagi::CBOR::Encoder.encode(long_string)
      decoded = described_class.decode(encoded)
      expect(decoded).to eq(long_string)
    end

    it 'handles empty collections' do
      expect(described_class.decode("\x80")).to eq([]) # Empty array
      expect(described_class.decode("\xA0")).to eq({}) # Empty map
      expect(described_class.decode("\x60")).to eq('') # Empty string
    end

    it 'preserves data types through roundtrip' do
      data = {
        'int' => 42,
        'float' => 3.14,
        'string' => 'hello',
        'bool' => true,
        'null' => nil,
        'array' => [1, 2, 3],
        'nested' => { 'key' => 'value' }
      }
      encoded = Takagi::CBOR::Encoder.encode(data)
      decoded = described_class.decode(encoded)

      expect(decoded['int']).to be_an(Integer)
      expect(decoded['float']).to be_a(Float)
      expect(decoded['string']).to be_a(String)
      expect(decoded['bool']).to be(true)
      expect(decoded['null']).to be_nil
      expect(decoded['array']).to be_an(Array)
      expect(decoded['nested']).to be_a(Hash)
    end
  end
end