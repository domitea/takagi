# frozen_string_literal: true

RSpec.describe Takagi::Serialization do
  describe 'Registry' do
    let(:registry) { Takagi::Serialization::Registry }

    describe '.register' do
      it 'registers a serializer class' do
        expect(registry.supports?(50)).to be true # JSON is pre-registered
      end

      it 'registers a serializer instance' do
        serializer = Takagi::Serialization::TextSerializer.new
        registry.register(99, serializer)
        expect(registry.supports?(99)).to be true
      ensure
        registry.unregister(99)
      end
    end

    describe '.encode and .decode' do
      it 'encodes and decodes JSON' do
        data = { temp: 25, humidity: 60 }
        bytes = registry.encode(data, 50)
        decoded = registry.decode(bytes, 50)

        expect(decoded['temp']).to eq(25)
        expect(decoded['humidity']).to eq(60)
      end

      it 'encodes and decodes CBOR' do
        data = { temp: 25, humidity: 60 }
        bytes = registry.encode(data, 60)
        decoded = registry.decode(bytes, 60)

        expect(decoded['temp']).to eq(25)
        expect(decoded['humidity']).to eq(60)
      end

      it 'encodes and decodes text/plain' do
        data = 'Hello World'
        bytes = registry.encode(data, 0)
        decoded = registry.decode(bytes, 0)

        expect(decoded).to eq('Hello World')
      end

      it 'raises UnknownFormatError for unregistered format' do
        expect { registry.encode({}, 999) }.to raise_error(Takagi::Serialization::UnknownFormatError)
        expect { registry.decode('', 999) }.to raise_error(Takagi::Serialization::UnknownFormatError)
      end
    end

    describe '.supported_formats' do
      it 'returns list of registered formats' do
        formats = registry.supported_formats
        expect(formats).to include(0, 42, 50, 60)
      end
    end

    describe '.summary' do
      it 'returns human-readable summary' do
        summary = registry.summary
        expect(summary).to include('application/json')
        expect(summary).to include('application/cbor')
        expect(summary).to include('text/plain')
      end
    end
  end

  describe 'JsonSerializer' do
    let(:serializer) { Takagi::Serialization::JsonSerializer.new }

    it 'encodes hash to JSON' do
      result = serializer.encode({ a: 1, b: 2 })
      expect(result).to include('"a"')
      expect(result).to include('"b"')
    end

    it 'encodes array to JSON' do
      result = serializer.encode([1, 2, 3])
      expect(result).to eq('[1,2,3]')
    end

    it 'passes through strings' do
      result = serializer.encode('already json')
      expect(result).to eq('already json')
    end

    it 'decodes JSON to Ruby object' do
      result = serializer.decode('{"temp":25}')
      expect(result).to eq({ 'temp' => 25 })
    end

    it 'handles empty/nil payload' do
      expect(serializer.encode(nil)).to eq(''.b)
      expect(serializer.encode('')).to eq(''.b)
      expect(serializer.decode(nil)).to be_nil
      expect(serializer.decode('')).to be_nil
    end

    it 'raises DecodeError on invalid JSON' do
      expect { serializer.decode('{invalid}') }.to raise_error(Takagi::Serialization::DecodeError)
    end

    it 'reports correct content type' do
      expect(serializer.content_type).to eq('application/json')
      expect(serializer.content_format_code).to eq(50)
    end
  end

  describe 'CborSerializer' do
    let(:serializer) { Takagi::Serialization::CborSerializer.new }

    it 'encodes hash to CBOR' do
      result = serializer.encode({ temp: 25 })
      # Should be binary CBOR
      expect(result.encoding).to eq(Encoding::BINARY)
    end

    it 'decodes CBOR to Ruby object' do
      bytes = serializer.encode({ temp: 25 })
      result = serializer.decode(bytes)
      expect(result['temp']).to eq(25)
    end

    it 'handles various data types' do
      data = {
        int: 42,
        float: 3.14,
        string: 'hello',
        array: [1, 2, 3],
        bool: true,
        null: nil
      }

      bytes = serializer.encode(data)
      decoded = serializer.decode(bytes)

      expect(decoded['int']).to eq(42)
      expect(decoded['float']).to be_within(0.01).of(3.14)
      expect(decoded['string']).to eq('hello')
      expect(decoded['array']).to eq([1, 2, 3])
      expect(decoded['bool']).to be true
      expect(decoded['null']).to be_nil
    end

    it 'handles empty/nil payload' do
      expect(serializer.encode(nil)).to eq(''.b)
      expect(serializer.encode('')).to eq(''.b)
      expect(serializer.decode(nil)).to be_nil
      expect(serializer.decode('')).to be_nil
    end

    it 'reports correct content type' do
      expect(serializer.content_type).to eq('application/cbor')
      expect(serializer.content_format_code).to eq(60)
      expect(serializer.binary?).to be true
    end
  end

  describe 'TextSerializer' do
    let(:serializer) { Takagi::Serialization::TextSerializer.new }

    it 'encodes string to UTF-8' do
      result = serializer.encode('Hello World')
      expect(result).to eq('Hello World')
      expect(result.encoding).to eq(Encoding::BINARY)
    end

    it 'converts non-strings to text' do
      expect(serializer.encode(42)).to eq('42')
      expect(serializer.encode({ a: 1 })).to include('a')
    end

    it 'decodes UTF-8 text' do
      bytes = 'Hello World'.b
      result = serializer.decode(bytes)
      expect(result).to eq('Hello World')
      expect(result.encoding).to eq(Encoding::UTF_8)
    end

    it 'validates UTF-8 encoding' do
      invalid_utf8 = "\xFF\xFE".b
      expect { serializer.decode(invalid_utf8) }.to raise_error(Takagi::Serialization::DecodeError)
    end

    it 'handles empty/nil payload' do
      expect(serializer.encode(nil)).to eq(''.b)
      expect(serializer.encode('')).to eq(''.b)
      expect(serializer.decode(nil)).to be_nil
      expect(serializer.decode('')).to be_nil
    end

    it 'reports correct content type' do
      expect(serializer.content_type).to eq('text/plain')
      expect(serializer.content_format_code).to eq(0)
    end
  end

  describe 'OctetStreamSerializer' do
    let(:serializer) { Takagi::Serialization::OctetStreamSerializer.new }

    it 'passes through binary data' do
      data = "\x00\x01\x02\x03".b
      result = serializer.encode(data)
      expect(result).to eq(data)
    end

    it 'decodes to binary string' do
      bytes = "\x00\x01\x02\x03".b
      result = serializer.decode(bytes)
      expect(result).to eq(bytes)
      expect(result.encoding).to eq(Encoding::BINARY)
    end

    it 'converts non-binary to binary' do
      result = serializer.encode('hello')
      expect(result.encoding).to eq(Encoding::BINARY)
    end

    it 'handles empty/nil payload' do
      expect(serializer.encode(nil)).to eq(''.b)
      expect(serializer.encode('')).to eq(''.b)
      expect(serializer.decode(nil)).to be_nil
      expect(serializer.decode('')).to be_nil
    end

    it 'reports correct content type' do
      expect(serializer.content_type).to eq('application/octet-stream')
      expect(serializer.content_format_code).to eq(42)
      expect(serializer.binary?).to be true
    end
  end

  describe 'Integration with Outbound' do
    it 'serializes payload with JSON (default)' do
      msg = Takagi::Message::Outbound.new(
        code: 69,
        payload: { temp: 25 }
      )

      expect(msg.payload).to include('temp')
      expect(msg.payload).to include('25')
    end

    it 'serializes payload with CBOR' do
      msg = Takagi::Message::Outbound.new(
        code: 69,
        payload: { temp: 25 },
        options: { 12 => 60 }  # Content-Format: CBOR
      )

      # Payload should be CBOR-encoded
      expect(msg.payload.encoding).to eq(Encoding::BINARY)
      # Should be decodable
      decoded = Takagi::CBOR::Decoder.decode(msg.payload)
      expect(decoded['temp']).to eq(25)
    end

    it 'serializes payload with text/plain' do
      msg = Takagi::Message::Outbound.new(
        code: 69,
        payload: 'Hello',
        options: { 12 => 0 }  # Content-Format: text/plain
      )

      expect(msg.payload).to eq('Hello')
    end

    it 'passes through strings regardless of format' do
      msg = Takagi::Message::Outbound.new(
        code: 69,
        payload: 'already serialized',
        options: { 12 => 50 }  # Content-Format: JSON
      )

      expect(msg.payload).to eq('already serialized')
    end
  end

  describe 'Integration with Client::Response' do
    it 'deserializes JSON payload with #data' do
      raw_data = build_coap_response(code: 69, payload: '{"temp":25}', content_format: 50)
      response = Takagi::Client::Response.new(raw_data)

      data = response.data
      expect(data).to eq({ 'temp' => 25 })
    end

    it 'deserializes CBOR payload with #data' do
      cbor_bytes = Takagi::CBOR::Encoder.encode({ temp: 25 })
      raw_data = build_coap_response(code: 69, payload: cbor_bytes, content_format: 60)
      response = Takagi::Client::Response.new(raw_data)

      data = response.data
      expect(data['temp']).to eq(25)
    end

    it 'deserializes text payload with #data' do
      raw_data = build_coap_response(code: 69, payload: 'Hello', content_format: 0)
      response = Takagi::Client::Response.new(raw_data)

      data = response.data
      expect(data).to eq('Hello')
    end

    it 'falls back to JSON for unknown format' do
      raw_data = build_coap_response(code: 69, payload: '{"temp":25}', content_format: 999)
      response = Takagi::Client::Response.new(raw_data)

      data = response.data
      expect(data).to eq({ 'temp' => 25 })
    end

    it 'returns raw payload on decode error' do
      raw_data = build_coap_response(code: 69, payload: '{invalid', content_format: 50)
      response = Takagi::Client::Response.new(raw_data)

      data = response.data
      expect(data).to eq('{invalid')
    end
  end

  # Helper to build CoAP response packet
  def build_coap_response(code:, payload:, content_format: nil)
    version = 1
    type = 2  # ACK
    token_length = 0
    message_id = 1234

    header = [(version << 6) | (type << 4) | token_length, code, message_id].pack('CCn')

    options_data = ''.b
    if content_format
      # Encode Content-Format option (12)
      delta = 12
      length = content_format <= 255 ? 1 : 2
      options_data << [(delta << 4) | length].pack('C')
      options_data << (content_format <= 255 ? [content_format].pack('C') : [content_format].pack('n'))
    end

    payload_marker = payload && !payload.empty? ? "\xFF".b : ''.b
    payload_data = payload || ''.b

    header + options_data + payload_marker + payload_data
  end
end
