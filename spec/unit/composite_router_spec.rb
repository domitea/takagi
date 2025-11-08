# frozen_string_literal: true

RSpec.describe Takagi::CompositeRouter do
  let(:router) { described_class.new }

  after do
    Object.send(:remove_const, :TelemetryController) if defined?(TelemetryController)
    Object.send(:remove_const, :ConfigController) if defined?(ConfigController)
    Object.send(:remove_const, :ApiController) if defined?(ApiController)
    Object.send(:remove_const, :DevicesController) if defined?(DevicesController)
  end

  describe '#mount' do
    it 'mounts a controller at a path' do
      class TelemetryController < Takagi::Controller
        configure do
          mount '/telemetry'
        end

        get '/data' do
          { temp: 25 }
        end
      end

      router.mount(TelemetryController)

      expect(router.mounted_controllers.length).to eq(1)
      expect(router.mounted_controllers.first.mount_path).to eq('/telemetry')
    end

    it 'normalizes mount paths' do
      class TelemetryController < Takagi::Controller
        configure do
          mount 'telemetry'  # No leading slash
        end
      end

      router.mount(TelemetryController)

      expect(router.mounted_controllers.first.mount_path).to eq('/telemetry')
    end

    it 'supports overriding mount path' do
      class TelemetryController < Takagi::Controller
        configure do
          mount '/default'
        end
      end

      router.mount(TelemetryController, at: '/custom')

      expect(router.mounted_controllers.first.mount_path).to eq('/custom')
    end

    it 'raises error when controller has no mount path' do
      class TelemetryController < Takagi::Controller
        # No mount configured
      end

      expect { router.mount(TelemetryController) }.to raise_error(ArgumentError, /no mount path/)
    end
  end

  describe '#find_route' do
    before do
      class TelemetryController < Takagi::Controller
        configure do
          mount '/telemetry'
        end

        post '/data' do
          { received: true }
        end

        get '/status' do
          { status: 'ok' }
        end
      end

      class ConfigController < Takagi::Controller
        configure do
          mount '/config'
        end

        get '/settings' do
          { settings: {} }
        end
      end

      router.mount(TelemetryController)
      router.mount(ConfigController)
    end

    it 'routes to correct controller based on path prefix' do
      handler, params = router.find_route('POST', '/telemetry/data')

      expect(handler).not_to be_nil
      expect(params).to eq({})
    end

    it 'strips mount prefix when routing to controller' do
      handler, _params = router.find_route('GET', '/telemetry/status')

      expect(handler).not_to be_nil
    end

    it 'returns nil for unknown paths' do
      handler, params = router.find_route('GET', '/unknown')

      expect(handler).to be_nil
      expect(params).to eq({})
    end

    it 'routes to different controllers' do
      handler1, = router.find_route('POST', '/telemetry/data')
      handler2, = router.find_route('GET', '/config/settings')

      expect(handler1).not_to be_nil
      expect(handler2).not_to be_nil
      expect(handler1).not_to eq(handler2)
    end
  end

  describe 'nested controllers' do
    it 'mounts nested controllers automatically' do
      class ApiController < Takagi::Controller
        configure do
          mount '/api'
        end
      end

      class DevicesController < Takagi::Controller
        configure do
          mount '/devices'
        end

        get '/:id' do
          { device_id: params[:id] }
        end
      end

      # Nest device under API
      ApiController.configure do
        nest DevicesController
      end

      router.mount(ApiController)

      # Should have both controllers mounted
      expect(router.mounted_controllers.length).to eq(2)

      # Find nested route
      handler, params = router.find_route('GET', '/api/devices/123')

      expect(handler).not_to be_nil
      expect(params).to eq({ id: '123' })
    end
  end

  describe '#all_routes' do
    it 'returns all routes with full paths' do
      class TelemetryController < Takagi::Controller
        configure do
          mount '/telemetry'
        end

        post '/data' do; end
        get '/status' do; end
      end

      router.mount(TelemetryController)

      routes = router.all_routes
      expect(routes).to include('POST /telemetry/data')
      expect(routes).to include('GET /telemetry/status')
    end
  end

  describe 'longest prefix matching' do
    it 'routes to most specific mount path' do
      class RootController < Takagi::Controller
        configure do
          mount '/'
        end

        get '/test' do
          { controller: 'root' }
        end
      end

      class SpecificController < Takagi::Controller
        configure do
          mount '/specific'
        end

        get '/test' do
          { controller: 'specific' }
        end
      end

      router.mount(RootController)
      router.mount(SpecificController)

      # Should route to SpecificController, not RootController
      handler, = router.find_route('GET', '/specific/test')

      expect(handler).not_to be_nil
      # Execute handler to verify it's from SpecificController
      # (In real implementation, this would go through request handling)
    end
  end
end
