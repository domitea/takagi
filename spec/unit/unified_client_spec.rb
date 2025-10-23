# frozen_string_literal: true

RSpec.describe Takagi::Client do
  describe 'unified API' do
    describe 'protocol detection' do
      it 'detects UDP from coap:// scheme' do
        client = described_class.new('coap://localhost:5683')
        expect(client.instance_variable_get(:@protocol)).to eq(:udp)
        expect(client.instance_variable_get(:@impl)).to be_a(Takagi::UdpClient)
        client.close
      end

      it 'detects TCP from coap+tcp:// scheme' do
        client = described_class.new('coap+tcp://localhost:5683')
        expect(client.instance_variable_get(:@protocol)).to eq(:tcp)
        expect(client.instance_variable_get(:@impl)).to be_a(Takagi::TcpClient)
        client.close
      end

      it 'defaults to UDP when no scheme is provided' do
        client = described_class.new('localhost:5683')
        expect(client.instance_variable_get(:@protocol)).to eq(:udp)
        expect(client.instance_variable_get(:@impl)).to be_a(Takagi::UdpClient)
        client.close
      end
    end

    describe 'explicit protocol parameter' do
      it 'uses UDP when protocol: :udp is specified' do
        client = described_class.new('localhost:5683', protocol: :udp)
        expect(client.instance_variable_get(:@protocol)).to eq(:udp)
        expect(client.instance_variable_get(:@impl)).to be_a(Takagi::UdpClient)
        client.close
      end

      it 'uses TCP when protocol: :tcp is specified' do
        client = described_class.new('localhost:5683', protocol: :tcp)
        expect(client.instance_variable_get(:@protocol)).to eq(:tcp)
        expect(client.instance_variable_get(:@impl)).to be_a(Takagi::TcpClient)
        client.close
      end

      it 'overrides URI scheme when protocol is explicitly specified' do
        client = described_class.new('coap://localhost:5683', protocol: :tcp)
        expect(client.instance_variable_get(:@protocol)).to eq(:tcp)
        expect(client.instance_variable_get(:@impl)).to be_a(Takagi::TcpClient)
        client.close
      end
    end

    describe 'block-based initialization' do
      it 'yields client and auto-closes with UDP' do
        closed_inside = nil

        described_class.new('coap://localhost:5683') do |client|
          closed_inside = client.closed?
          expect(client.instance_variable_get(:@impl)).to be_a(Takagi::UdpClient)
        end

        expect(closed_inside).to be false
      end

      it 'yields client and auto-closes with TCP' do
        closed_inside = nil

        described_class.new('localhost:5683', protocol: :tcp) do |client|
          closed_inside = client.closed?
          expect(client.instance_variable_get(:@impl)).to be_a(Takagi::TcpClient)
        end

        expect(closed_inside).to be false
      end

      it 'auto-closes even when an error occurs' do
        client_ref = nil

        expect do
          described_class.new('coap://localhost:5683') do |client|
            client_ref = client
            raise 'Test error'
          end
        end.to raise_error('Test error')

        sleep 0.2 # Give thread time to stop
        expect(client_ref.closed?).to be true
      end
    end

    describe 'manual lifecycle management' do
      it 'requires explicit close without block' do
        client = described_class.new('coap://localhost:5683')
        expect(client.closed?).to be false

        client.close
        expect(client.closed?).to be true
      end

      it 'delegates close to implementation' do
        client = described_class.new('coap://localhost:5683')
        impl = client.instance_variable_get(:@impl)

        expect(impl).to receive(:close).and_call_original
        client.close
      end
    end

    describe 'method delegation' do
      it 'delegates get, post, put, delete to implementation' do
        client = described_class.new('coap://localhost:5683')

        expect(client).to respond_to(:get)
        expect(client).to respond_to(:post)
        expect(client).to respond_to(:put)
        expect(client).to respond_to(:delete)
        expect(client).to respond_to(:on)

        client.close
      end

      it 'delegates callbacks to implementation' do
        client = described_class.new('coap://localhost:5683')
        impl = client.instance_variable_get(:@impl)

        callback = proc { |response| response }
        client.on(:response, &callback)

        expect(impl.callbacks[:response]).to eq(callback)
        client.close
      end
    end

    describe 'error handling' do
      it 'raises error for unknown protocol' do
        # Manually set invalid protocol
        expect do
          client = described_class.allocate
          client.instance_variable_set(:@protocol, :invalid)
          client.send(:create_client_impl, 'localhost:5683', 5, true)
        end.to raise_error(ArgumentError, /Unknown protocol/)
      end
    end
  end
end
