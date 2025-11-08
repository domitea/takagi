# frozen_string_literal: true

RSpec.describe 'Application CoRE Discovery' do
  after do
    Object.send(:remove_const, :TelemetryController) if defined?(TelemetryController)
    Object.send(:remove_const, :TestApp) if defined?(TestApp)
  end

  it 'automatically provides /.well-known/core endpoint' do
    class TelemetryController < Takagi::Controller
      configure do
        mount '/telemetry'
      end

      post '/data', metadata: { rt: 'sensor.data' } do
        { received: true }
      end
    end

    class TestApp < Takagi::Application
      configure do
        load_controllers TelemetryController
      end
    end

    TestApp.load_controllers!

    # Check that discovery endpoint exists
    handler, _params = TestApp.router.find_route('GET', '/.well-known/core')
    expect(handler).not_to be_nil
  end

  it 'discovery endpoint returns resources from all controllers' do
    class TelemetryController < Takagi::Controller
      configure do
        mount '/telemetry'
      end

      post '/data', metadata: { rt: 'sensor.data' } do; end
      get '/stats', metadata: { rt: 'sensor.stats' } do; end
    end

    class TestApp < Takagi::Application
      configure do
        load_controllers TelemetryController
      end
    end

    TestApp.load_controllers!

    # Create mock request
    mock_request = double('request')
    allow(mock_request).to receive(:uri).and_return(double('uri', query: nil))
    allow(mock_request).to receive(:to_response) { |code, payload, opts| payload }

    # Get discovery handler
    handler, = TestApp.router.find_route('GET', '/.well-known/core')

    # Execute handler
    result = handler.call(mock_request, {})

    # Should include resources from TelemetryController
    expect(result).to include('</telemetry/data>')
    expect(result).to include('</telemetry/stats>')
    expect(result).to include('rt="sensor.data"')
    expect(result).to include('rt="sensor.stats"')
  end

  it 'discovery endpoint filters by query parameters' do
    class TelemetryController < Takagi::Controller
      configure do
        mount '/telemetry'
      end

      post '/temp', metadata: { rt: 'sensor.temp' } do; end
      post '/humidity', metadata: { rt: 'sensor.humidity' } do; end
    end

    class TestApp < Takagi::Application
      configure do
        load_controllers TelemetryController
      end
    end

    TestApp.load_controllers!

    # Create mock request with query
    mock_request = double('request')
    mock_uri = double('uri', query: 'rt=sensor.temp')
    allow(mock_request).to receive(:uri).and_return(mock_uri)
    allow(mock_request).to receive(:to_response) { |code, payload, opts| payload }

    # Get discovery handler
    handler, = TestApp.router.find_route('GET', '/.well-known/core')

    # Execute handler with query
    result = handler.call(mock_request, {})

    # Should only include temp sensor
    expect(result).to include('</telemetry/temp>')
    expect(result).not_to include('</telemetry/humidity>')
  end
end
