# frozen_string_literal: true

RSpec.describe Takagi::Controller do
  # Clean up router instances between tests
  after do
    Object.send(:remove_const, :TestController) if defined?(TestController)
    Object.send(:remove_const, :ParentController) if defined?(ParentController)
    Object.send(:remove_const, :ChildController) if defined?(ChildController)
  end

  describe '.router' do
    it 'creates an isolated router instance' do
      class TestController < Takagi::Controller; end

      expect(TestController.router).to be_a(Takagi::Router)
      expect(TestController.router).not_to eq(Takagi::Router.instance) # Not the global singleton
    end

    it 'each controller has its own router' do
      class TestController1 < Takagi::Controller; end
      class TestController2 < Takagi::Controller; end

      expect(TestController1.router).not_to eq(TestController2.router)
    end
  end

  describe '.config' do
    it 'creates a configuration hash' do
      class TestController < Takagi::Controller; end

      expect(TestController.config).to be_a(Hash)
      expect(TestController.config).to include(:mount_path, :profile, :processes, :threads)
    end
  end

  describe '.configure' do
    it 'allows configuration via DSL block' do
      class TestController < Takagi::Controller
        configure do
          mount '/test'
          profile :low_traffic
          set :processes, 4
        end
      end

      expect(TestController.config[:mount_path]).to eq('/test')
      expect(TestController.config[:profile]).to eq(:low_traffic)
      expect(TestController.config[:processes]).to eq(4)
    end
  end

  describe 'route registration' do
    it 'registers routes with isolated router' do
      class TestController < Takagi::Controller
        get '/test' do
          { message: 'test' }
        end

        post '/data' do
          { received: true }
        end
      end

      routes = TestController.router.all_routes
      expect(routes).to include('GET /test')
      expect(routes).to include('POST /data')
    end

    it 'supports observable routes' do
      class TestController < Takagi::Controller
        observable '/events' do
          { event: 'test' }
        end
      end

      entry = TestController.router.find_observable('/events')
      expect(entry).not_to be_nil
      expect(entry.method).to eq('OBSERVE')
    end

    it 'routes are isolated between controllers' do
      class TestController1 < Takagi::Controller
        get '/test1' do; end
      end

      class TestController2 < Takagi::Controller
        get '/test2' do; end
      end

      expect(TestController1.router.all_routes).to include('GET /test1')
      expect(TestController1.router.all_routes).not_to include('GET /test2')

      expect(TestController2.router.all_routes).to include('GET /test2')
      expect(TestController2.router.all_routes).not_to include('GET /test1')
    end
  end

  describe '.mount_path' do
    it 'returns the configured mount path' do
      class TestController < Takagi::Controller
        configure do
          mount '/telemetry'
        end
      end

      expect(TestController.mount_path).to eq('/telemetry')
    end

    it 'returns nil when not configured' do
      class TestController < Takagi::Controller; end

      expect(TestController.mount_path).to be_nil
    end

    it 'resolves nested paths from parent' do
      class ParentController < Takagi::Controller
        configure do
          mount '/api'
        end
      end

      class ChildController < Takagi::Controller
        configure do
          mount '/devices', nested_from: ParentController
        end
      end

      expect(ChildController.mount_path).to eq('/api/devices')
    end
  end

  describe '.mounted?' do
    it 'returns true when controller has mount path' do
      class TestController < Takagi::Controller
        configure do
          mount '/test'
        end
      end

      expect(TestController.mounted?).to be true
    end

    it 'returns false when controller has no mount path' do
      class TestController < Takagi::Controller; end

      expect(TestController.mounted?).to be false
    end
  end

  describe 'nesting' do
    it 'nests child controllers via parent' do
      class ParentController < Takagi::Controller
        configure do
          mount '/parent'
        end
      end

      class ChildController < Takagi::Controller
        configure do
          mount '/child'
        end
      end

      # Nest child under parent
      ParentController.configure do
        nest ChildController
      end

      expect(ParentController.nested_controllers).to include(ChildController)
      expect(ChildController.config[:nested_from]).to eq(ParentController)
      expect(ChildController.mount_path).to eq('/parent/child')
    end

    it 'supports child referencing parent' do
      class ParentController < Takagi::Controller
        configure do
          mount '/parent'
        end
      end

      class ChildController < Takagi::Controller
        configure do
          mount '/child', nested_from: ParentController
        end
      end

      expect(ChildController.config[:nested_from]).to eq(ParentController)
      expect(ChildController.mount_path).to eq('/parent/child')
    end
  end

  describe 'profiles' do
    it 'sets load profile' do
      class TestController < Takagi::Controller
        configure do
          profile :high_throughput
        end
      end

      expect(TestController.profile_name).to eq(:high_throughput)
      expect(TestController.process_count).to eq(8)
      expect(TestController.thread_count).to eq(4)
    end

    it 'allows overriding profile values' do
      class TestController < Takagi::Controller
        configure do
          profile :high_throughput
          set :processes, 16
        end
      end

      expect(TestController.profile_name).to eq(:high_throughput)
      expect(TestController.process_count).to eq(16) # Override
      expect(TestController.thread_count).to eq(4)   # From profile
    end

    it 'raises error for unknown profile' do
      expect do
        class TestController < Takagi::Controller
          configure do
            profile :unknown_profile
          end
        end
      end.to raise_error(ArgumentError, /Unknown profile/)
    end
  end

  describe 'configuration' do
    it 'supports manual process/thread configuration' do
      class TestController < Takagi::Controller
        configure do
          set :processes, 4
          set :threads, 8
        end
      end

      expect(TestController.process_count).to eq(4)
      expect(TestController.thread_count).to eq(8)
    end

    it 'returns nil when no profile or manual config' do
      class TestController < Takagi::Controller; end

      expect(TestController.process_count).to be_nil
      expect(TestController.thread_count).to be_nil
    end
  end
end
