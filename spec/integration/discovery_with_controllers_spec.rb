# frozen_string_literal: true

RSpec.describe 'CoRE Link Format Discovery with Controllers' do
  after do
    Object.send(:remove_const, :TelemetryController) if defined?(TelemetryController)
    Object.send(:remove_const, :ConfigController) if defined?(ConfigController)
    Object.send(:remove_const, :TestApp) if defined?(TestApp)
  end

  it 'generates CoRE Link Format from multiple controllers' do
    class TelemetryController < Takagi::Controller
      configure do
        mount '/telemetry'
      end

      post '/data', metadata: { rt: 'sensor.data', if: 'core.s' } do
        { received: true }
      end

      get '/stats', metadata: { rt: 'sensor.stats' } do
        { count: 100 }
      end
    end

    class ConfigController < Takagi::Controller
      configure do
        mount '/config'
      end

      get '/settings', metadata: { rt: 'core.config' } do
        { setting: 'value' }
      end
    end

    class TestApp < Takagi::Application
      configure do
        load_controllers TelemetryController, ConfigController
      end
    end

    # Load controllers
    TestApp.load_controllers!

    # Get link format entries from composite router
    entries = TestApp.router.link_format_entries

    # Should have entries from both controllers
    paths = entries.map(&:path)
    expect(paths).to include('/telemetry/data')
    expect(paths).to include('/telemetry/stats')
    expect(paths).to include('/config/settings')

    # Check metadata is preserved
    telemetry_entry = entries.find { |e| e.path == '/telemetry/data' }
    expect(telemetry_entry.metadata[:rt]).to eq('sensor.data')
    expect(telemetry_entry.metadata[:if]).to eq('core.s')
  end

  it 'generates proper CoRE Link Format string' do
    class TelemetryController < Takagi::Controller
      configure do
        mount '/telemetry'
      end

      post '/data', metadata: { rt: 'sensor.data', ct: 50 } do
        { received: true }
      end
    end

    class TestApp < Takagi::Application
      configure do
        load_controllers TelemetryController
      end
    end

    TestApp.load_controllers!

    # Generate CoRE Link Format
    link_format = Takagi::Discovery::CoreLinkFormat.generate(router: TestApp.router)

    # Should include the mounted path
    expect(link_format).to include('</telemetry/data>')
    expect(link_format).to include('rt="sensor.data"')
    expect(link_format).to include('ct=50')
  end

  it 'works with nested controllers' do
    class ApiController < Takagi::Controller
      configure do
        mount '/api'
      end
    end

    class SensorsController < Takagi::Controller
      configure do
        mount '/sensors'
      end

      get '/:id', metadata: { rt: 'sensor' } do
        { id: params[:id] }
      end
    end

    # Nest sensors under API
    ApiController.configure do
      nest SensorsController
    end

    class TestApp < Takagi::Application
      configure do
        load_controllers ApiController
      end
    end

    TestApp.load_controllers!

    # Generate link format
    link_format = Takagi::Discovery::CoreLinkFormat.generate(router: TestApp.router)

    # Should include full nested path
    expect(link_format).to include('</api/sensors/:id>')
  end

  it 'filters resources by query parameters' do
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

    # Create a mock request with query
    mock_request = double('request')
    mock_uri = double('uri', query: 'rt=sensor.temp')
    allow(mock_request).to receive(:uri).and_return(mock_uri)

    # Generate filtered link format
    link_format = Takagi::Discovery::CoreLinkFormat.generate(
      router: TestApp.router,
      request: mock_request
    )

    # Should only include temperature sensor
    expect(link_format).to include('</telemetry/temp>')
    expect(link_format).not_to include('</telemetry/humidity>')
  end
end
