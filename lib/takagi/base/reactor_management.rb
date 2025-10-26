# frozen_string_literal: true

module Takagi
  class Base < Router
    # Manages reactor registration and lifecycle for observable/observer patterns.
    #
    # Extracted from Base class to follow Single Responsibility Principle.
    # Handles reactor DSL blocks and reactor class registration.
    module ReactorManagement
      # Defines a reactor using a DSL block
      #
      # The block is evaluated in the context of a new Reactor instance,
      # allowing you to define observables and observers inline.
      #
      # @yield Block defining reactor configuration
      #
      # @example
      #   reactor do
      #     observable '/temperature' do
      #       { value: current_temp, unit: 'C' }
      #     end
      #
      #     observer 'coap://other-node:5683/alerts' do |notification|
      #       handle_alert(notification)
      #     end
      #   end
      def reactor(&block)
        reactor_instance = Takagi::Reactor.new
        reactor_instance.instance_eval(&block)
        Takagi::ReactorRegistry.register(reactor_instance)
      end

      # Registers a reactor class instance
      #
      # Useful when you have a custom reactor class that you want to instantiate
      # and register with the reactor registry.
      #
      # @param klass [Class] Reactor class to instantiate
      #
      # @example
      #   class CustomReactor < Takagi::Reactor
      #     def initialize
      #       super
      #       # custom setup
      #     end
      #   end
      #
      #   use_reactor CustomReactor
      def use_reactor(klass)
        reactor_instance = klass.new
        Takagi::ReactorRegistry.register(reactor_instance)
      end

      # Starts all registered reactors
      #
      # Called automatically by server lifecycle management during boot.
      # Can be called manually if needed.
      def start_reactors
        Takagi::ReactorRegistry.start_all
      end
    end
  end
end
