# frozen_string_literal: true

module Takagi
  # Application class for modular controller-based apps
  #
  # Application provides a centralized way to mount and manage multiple
  # controllers, auto-load controller files, and run the server.
  #
  # @example Simple application
  #   class MyApp < Takagi::Application
  #     configure do
  #       load_controllers TelemetryController, ConfigController
  #     end
  #   end
  #
  #   MyApp.run!(port: 5683)
  #
  # @example With auto-loading
  #   class MyApp < Takagi::Application
  #     configure do
  #       auto_load 'app/controllers/**/*_controller.rb'
  #     end
  #   end
  #
  #   MyApp.run!
  class Application
    # Internal controller for CoRE Link Format discovery endpoint
    # Automatically mounted by Application
    class DiscoveryController < Controller
      @@app_router = nil

      def self.app_router=(router)
        @@app_router = router
      end

      def self.app_router
        @@app_router
      end

      configure do
        mount '/.well-known'
      end

      get '/core', metadata: {
        rt: 'core.discovery',
        if: 'core.rd',
        ct: Discovery::CoreLinkFormat::CONTENT_FORMAT,
        discovery: true,
        title: 'Resource Discovery'
      } do |req|
        # Get the composite router from the application
        app_router = DiscoveryController.app_router
        payload = Discovery::CoreLinkFormat.generate(router: app_router, request: req)
        req.to_response(
          '2.05 Content',
          payload,
          options: { CoAP::Option::CONTENT_FORMAT => Discovery::CoreLinkFormat::CONTENT_FORMAT }
        )
      end
    end

    class << self
      # Get the application's composite router
      #
      # @return [CompositeRouter] The application's router
      def router
        @router ||= CompositeRouter.new
      end

      # Get the application's configuration
      #
      # @return [Hash] Configuration hash
      def config
        @config ||= {
          controllers: [],
          auto_load_patterns: []
        }
      end

      # Configure the application
      #
      # @yield Block for configuration DSL
      #
      # @example
      #   configure do
      #     load_controllers TelemetryController, ConfigController
      #     auto_load 'app/controllers/**/*_controller.rb'
      #   end
      def configure(&block)
        ConfigContext.new(self).instance_eval(&block) if block
      end

      # Load and mount all registered controllers
      #
      # @return [void]
      def load_controllers!
        # Load auto-discovered controllers
        auto_load_controllers! if config[:auto_load_patterns].any?

        # Mount discovery controller first (so it's available at /.well-known/core)
        # Store reference to composite router for discovery endpoint
        DiscoveryController.app_router = router
        router.mount(DiscoveryController)

        # Mount all registered controllers
        config[:controllers].each do |controller_class|
          router.mount(controller_class)
        end
      end

      # Run the application server
      #
      # @param options [Hash] Server options (port, protocols, etc.)
      # @return [void]
      #
      # @example
      #   MyApp.run!(port: 5683, protocols: [:udp, :tcp])
      def run!(**options)
        # Load all controllers
        load_controllers!

        # Use the composite router instead of global singleton
        options[:router] = router

        # Delegate to server lifecycle (same as Takagi::Base)
        Base::ServerLifecycle.run!(**options)
      end

      # Get all loaded controller classes
      #
      # @return [Array<Class>] List of controller classes
      def controllers
        config[:controllers]
      end

      private

      # Auto-load controllers from file patterns
      #
      # @return [void]
      def auto_load_controllers!
        config[:auto_load_patterns].each do |pattern|
          Dir.glob(pattern).each do |file|
            require_relative file
          end
        end
      end
    end

    # Configuration DSL context for Application
    class ConfigContext
      def initialize(app_class)
        @app = app_class
      end

      # Load specific controller classes
      #
      # @param controllers [Array<Class>] Controller classes to load
      #
      # @example
      #   load_controllers TelemetryController, ConfigController
      def load_controllers(*controllers)
        @app.config[:controllers].concat(controllers)
      end

      # Auto-load controllers from file pattern
      #
      # @param pattern [String] Glob pattern for controller files
      #
      # @example
      #   auto_load 'app/controllers/**/*_controller.rb'
      def auto_load(pattern)
        @app.config[:auto_load_patterns] << pattern
      end
    end
  end
end
