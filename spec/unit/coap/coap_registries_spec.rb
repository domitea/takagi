# frozen_string_literal: true

RSpec.describe 'CoAP Registries' do
  describe Takagi::CoAP::Method do
    it 'provides standard method constants' do
      expect(Takagi::CoAP::Method::GET).to eq(1)
      expect(Takagi::CoAP::Method::POST).to eq(2)
      expect(Takagi::CoAP::Method::PUT).to eq(3)
      expect(Takagi::CoAP::Method::DELETE).to eq(4)
    end

    it 'provides method names' do
      expect(Takagi::CoAP::Method.name_for(1)).to eq('GET')
      expect(Takagi::CoAP::Method.name_for(2)).to eq('POST')
    end

    it 'validates method codes' do
      expect(Takagi::CoAP::Method.valid?(1)).to be true
      expect(Takagi::CoAP::Method.valid?(99)).to be false
    end

    it 'allows plugins to register custom methods' do
      Takagi::CoAP::Method.register(5, 'FETCH', :fetch, rfc: 'RFC 8132')
      expect(Takagi::CoAP::Method::FETCH).to eq(5)
      expect(Takagi::CoAP::Method.name_for(5)).to eq('FETCH')
    ensure
      # Cleanup
      Takagi::CoAP::Method.instance_variable_get(:@registry).delete(5)
      Takagi::CoAP::Method.send(:remove_const, :FETCH) if Takagi::CoAP::Method.const_defined?(:FETCH, false)
    end
  end

  describe Takagi::CoAP::Response do
    it 'provides standard response constants' do
      expect(Takagi::CoAP::Response::CONTENT).to eq(69)
      expect(Takagi::CoAP::Response::NOT_FOUND).to eq(132)
      expect(Takagi::CoAP::Response::INTERNAL_SERVER_ERROR).to eq(160)
    end

    it 'provides response names with dotted notation' do
      expect(Takagi::CoAP::Response.name_for(69)).to eq('2.05 Content')
      expect(Takagi::CoAP::Response.name_for(132)).to eq('4.04 Not Found')
    end

    it 'identifies success codes' do
      expect(Takagi::CoAP::Response.success?(69)).to be true
      expect(Takagi::CoAP::Response.success?(132)).to be false
    end

    it 'identifies client errors' do
      expect(Takagi::CoAP::Response.client_error?(132)).to be true
      expect(Takagi::CoAP::Response.client_error?(69)).to be false
    end

    it 'identifies server errors' do
      expect(Takagi::CoAP::Response.server_error?(160)).to be true
      expect(Takagi::CoAP::Response.server_error?(69)).to be false
    end

    it 'identifies any errors' do
      expect(Takagi::CoAP::Response.error?(132)).to be true
      expect(Takagi::CoAP::Response.error?(160)).to be true
      expect(Takagi::CoAP::Response.error?(69)).to be false
    end

    it 'allows plugins to register custom response codes' do
      Takagi::CoAP::Response.register(231, '7.07 Custom', :custom)
      expect(Takagi::CoAP::Response::CUSTOM).to eq(231)
      expect(Takagi::CoAP::Response.name_for(231)).to eq('7.07 Custom')
    ensure
      # Cleanup
      Takagi::CoAP::Response.instance_variable_get(:@registry).delete(231)
      Takagi::CoAP::Response.send(:remove_const, :CUSTOM) if Takagi::CoAP::Response.const_defined?(:CUSTOM, false)
    end
  end

  describe Takagi::CoAP::Option do
    it 'provides standard option constants' do
      expect(Takagi::CoAP::Option::URI_PATH).to eq(11)
      expect(Takagi::CoAP::Option::CONTENT_FORMAT).to eq(12)
      expect(Takagi::CoAP::Option::URI_QUERY).to eq(15)
    end

    it 'provides option names' do
      expect(Takagi::CoAP::Option.name_for(11)).to eq('Uri-Path')
      expect(Takagi::CoAP::Option.name_for(12)).to eq('Content-Format')
    end

    it 'identifies critical options' do
      expect(Takagi::CoAP::Option.critical?(11)).to be true  # Uri-Path (odd)
      expect(Takagi::CoAP::Option.critical?(12)).to be false # Content-Format (even)
    end

    it 'allows plugins to register custom options' do
      Takagi::CoAP::Option.register(65000, 'Custom-Option', :custom_option)
      expect(Takagi::CoAP::Option::CUSTOM_OPTION).to eq(65000)
      expect(Takagi::CoAP::Option.name_for(65000)).to eq('Custom-Option')
    ensure
      # Cleanup
      Takagi::CoAP::Option.instance_variable_get(:@registry).delete(65000)
      Takagi::CoAP::Option.send(:remove_const, :CUSTOM_OPTION) if Takagi::CoAP::Option.const_defined?(:CUSTOM_OPTION, false)
    end
  end

  describe Takagi::CoAP::ContentFormat do
    it 'provides standard content-format constants' do
      expect(Takagi::CoAP::ContentFormat::TEXT_PLAIN).to eq(0)
      expect(Takagi::CoAP::ContentFormat::JSON).to eq(50)
      expect(Takagi::CoAP::ContentFormat::CBOR).to eq(60)
    end

    it 'provides MIME types' do
      expect(Takagi::CoAP::ContentFormat.mime_type_for(50)).to eq('application/json')
      expect(Takagi::CoAP::ContentFormat.mime_type_for(0)).to eq('text/plain')
    end

    it 'identifies JSON formats' do
      expect(Takagi::CoAP::ContentFormat.json?(50)).to be true
      expect(Takagi::CoAP::ContentFormat.json?(0)).to be false
    end

    it 'identifies text formats' do
      expect(Takagi::CoAP::ContentFormat.text?(0)).to be true
      expect(Takagi::CoAP::ContentFormat.text?(50)).to be false
    end

    it 'allows plugins to register custom formats' do
      Takagi::CoAP::ContentFormat.register(65001, 'application/custom', :custom)
      expect(Takagi::CoAP::ContentFormat::CUSTOM).to eq(65001)
      expect(Takagi::CoAP::ContentFormat.mime_type_for(65001)).to eq('application/custom')
    ensure
      # Cleanup
      Takagi::CoAP::ContentFormat.instance_variable_get(:@registry).delete(65001)
      Takagi::CoAP::ContentFormat.send(:remove_const, :CUSTOM) if Takagi::CoAP::ContentFormat.const_defined?(:CUSTOM, false)
    end
  end

  describe Takagi::CoAP::MessageType do
    it 'provides standard message type constants' do
      expect(Takagi::CoAP::MessageType::CONFIRMABLE).to eq(0)
      expect(Takagi::CoAP::MessageType::NON_CONFIRMABLE).to eq(1)
      expect(Takagi::CoAP::MessageType::ACKNOWLEDGEMENT).to eq(2)
      expect(Takagi::CoAP::MessageType::RESET).to eq(3)
    end

    it 'provides convenient aliases' do
      expect(Takagi::CoAP::MessageType::CON).to eq(0)
      expect(Takagi::CoAP::MessageType::NON).to eq(1)
      expect(Takagi::CoAP::MessageType::ACK).to eq(2)
      expect(Takagi::CoAP::MessageType::RST).to eq(3)
    end

    it 'provides type checking methods' do
      expect(Takagi::CoAP::MessageType.confirmable?(0)).to be true
      expect(Takagi::CoAP::MessageType.ack?(2)).to be true
      expect(Takagi::CoAP::MessageType.reset?(3)).to be true
    end
  end

  describe Takagi::CoAP::CodeHelpers do
    describe '.to_string' do
      it 'converts method codes to strings' do
        expect(Takagi::CoAP::CodeHelpers.to_string(1)).to eq('GET')
        expect(Takagi::CoAP::CodeHelpers.to_string(:post)).to eq('POST')
      end

      it 'converts response codes to strings' do
        expect(Takagi::CoAP::CodeHelpers.to_string(69)).to eq('2.05 Content')
        expect(Takagi::CoAP::CodeHelpers.to_string(:not_found)).to eq('4.04 Not Found')
      end

      it 'converts dotted strings' do
        expect(Takagi::CoAP::CodeHelpers.to_string('2.05')).to eq('2.05 Content')
      end
    end

    describe '.to_numeric' do
      it 'converts symbols to numeric codes' do
        expect(Takagi::CoAP::CodeHelpers.to_numeric(:get)).to eq(1)
        expect(Takagi::CoAP::CodeHelpers.to_numeric(:content)).to eq(69)
      end

      it 'converts dotted strings to numeric codes' do
        expect(Takagi::CoAP::CodeHelpers.to_numeric('2.05')).to eq(69)
        expect(Takagi::CoAP::CodeHelpers.to_numeric('4.04')).to eq(132)
      end

      it 'passes through integers' do
        expect(Takagi::CoAP::CodeHelpers.to_numeric(69)).to eq(69)
      end
    end

    describe '.numeric_to_string' do
      it 'converts to dotted notation' do
        expect(Takagi::CoAP::CodeHelpers.numeric_to_string(69)).to eq('2.05')
        expect(Takagi::CoAP::CodeHelpers.numeric_to_string(132)).to eq('4.04')
      end
    end

    describe '.string_to_numeric' do
      it 'converts from dotted notation' do
        expect(Takagi::CoAP::CodeHelpers.string_to_numeric('2.05')).to eq(69)
        expect(Takagi::CoAP::CodeHelpers.string_to_numeric('4.04')).to eq(132)
      end
    end

    describe 'status checking' do
      it 'identifies success codes' do
        expect(Takagi::CoAP::CodeHelpers.success?(69)).to be true
        expect(Takagi::CoAP::CodeHelpers.success?('2.05')).to be true
        expect(Takagi::CoAP::CodeHelpers.success?(:content)).to be true
      end

      it 'identifies error codes' do
        expect(Takagi::CoAP::CodeHelpers.error?(132)).to be true
        expect(Takagi::CoAP::CodeHelpers.client_error?('4.04')).to be true
        expect(Takagi::CoAP::CodeHelpers.server_error?(160)).to be true
      end
    end

    describe '.lookup' do
      it 'provides comprehensive code information' do
        info = Takagi::CoAP::CodeHelpers.lookup(69)
        expect(info[:value]).to eq(69)
        expect(info[:string]).to eq('2.05')
        expect(info[:name]).to eq('2.05 Content')
        expect(info[:type]).to eq(:response)
      end
    end
  end
end
