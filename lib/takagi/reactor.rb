# frozen_string_literal: true

module Takagi
  # Coordinates local observables and remote observe subscriptions.
  class Reactor
    def initialize
      @observables = {}
      @observes = []
      @watcher = Takagi::Observer::Watcher.new(interval: 1)
    end

    def observable(path, &block)
      @observables[path] = block
      Takagi::Base.router.observable(path, &block)
      Takagi::ObserveRegistry.subscriptions[path] ||= []
    end

    def observe(uri, &block)
      Takagi.logger.info("Observing remote resource: #{uri}")
      @observes << { uri: uri, handler: block }

      parsed = URI.parse(uri)
      path = parsed.path

      Takagi.logger.debug "Subscribing #{path} with fake subscriber"

      Takagi::ObserveRegistry.subscribe(
        path,
        address: parsed.host,
        port: parsed.port || 5683,
        token: SecureRandom.hex(2),
        handler: block
      )

      client = Takagi::Observer::Client.new(uri)
      client.on_notify(&block)
      client.subscribe
    end

    def trigger_observe(uri, value)
      path = URI.parse(uri).path
      Takagi.logger.debug "Trigger observe for path: #{path} with value: #{value}"
      Takagi::ObserveRegistry.notify(path, value)
    end

    def start
      @watcher.start
      Takagi.logger.debug "Reactor started with #{@observables.keys.size} local observables and #{@observes.size} remote observes"
    end
  end
end
