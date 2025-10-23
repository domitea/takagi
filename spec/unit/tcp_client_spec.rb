# frozen_string_literal: true

RSpec.describe Takagi::TcpClient do
  it 'sends request and receives response over TCP' do
    port = find_free_port
    server = Takagi::Base.spawn!(port: port, protocols: [:tcp])
    client = described_class.new("coap+tcp://127.0.0.1:#{port}")

    response = nil
    client.get('/ping') { |res| response = res }

    expect(response).to be_a(Takagi::Client::Response)
    expect(response.payload).to include('Pong')
    expect(response.success?).to be true
  ensure
    client&.close
    server.shutdown!
  end

  describe 'lifecycle management' do
    it 'has close method' do
      client = described_class.new('coap+tcp://127.0.0.1:5683')
      expect(client).to respond_to(:close)
      expect(client).to respond_to(:closed?)
      client.close
    end

    it 'supports block-based auto-close' do
      result = described_class.open('coap+tcp://127.0.0.1:5683') do |client|
        expect(client.closed?).to be false
        'test_result'
      end

      expect(result).to eq('test_result')
    end
  end
end
