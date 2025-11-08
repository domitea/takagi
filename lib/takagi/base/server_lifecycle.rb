# frozen_string_literal: true

module Takagi
  class Base < Router
    # Manages server lifecycle operations: booting, running, and spawning servers.
    #
    # Extracted from Base class to follow Single Responsibility Principle.
    # Handles configuration loading, server instantiation, and process management.
    module ServerLifecycle
      # Boots the application by loading configuration and running initializers
      #
      # @param config_path [String] Path to configuration file
      def boot!(config_path: 'config/takagi.yml')
        Takagi.config.load_file(config_path) if File.exist?(config_path)
        Takagi::Initializer.run!
      end

      # Runs the server in the foreground (blocking)
      #
      # @param port [Integer, nil] Port to bind to (uses config if nil)
      # @param config_path [String] Path to configuration file
      # @param protocols [Array<Symbol>, nil] Protocols to enable (uses config if nil)
      # @param router [Router, CompositeRouter, nil] Custom router (uses global if nil)
      def run!(port: nil, config_path: 'config/takagi.yml', protocols: nil, router: nil)
        boot!(config_path: config_path)
        selected_port = port || Takagi.config.port
        servers = build_servers(protocols || Takagi.config.protocols, selected_port, router: router)
        run_servers(servers)
      end

      # Spawns servers in background threads
      #
      # @param port [Integer] Port to bind to
      # @param protocols [Array<Symbol>, nil] Protocols to enable (uses config if nil)
      # @return [Server, Multi] The spawned server instance
      def spawn!(port: 5683, protocols: nil)
        protos = if protocols
                   Array(protocols)
                 else
                   Takagi.config.protocols
                 end.map(&:to_sym)

        servers = protos.map do |proto|
          # Temporary backward compatibility - will use registry after transition
          proto == :tcp ? Takagi::Server::Tcp.new(port: port) : Takagi::Server::Udp.new(port: port)
        end

        if servers.length == 1
          Thread.new { servers.first.run! }
          servers.first
        else
          multi = Takagi::Server::Multi.new(servers)
          Thread.new { multi.run! }
          multi
        end
      end

      private

      # Builds server instances for the given protocols
      #
      # @param protocols [Array<Symbol>] Protocol identifiers
      # @param port [Integer] Port to bind to
      # @param router [Router, CompositeRouter, nil] Custom router (uses global if nil)
      # @return [Array<Server>] Array of server instances
      def build_servers(protocols, port, router: nil)
        threads = Takagi.config.threads
        processes = Takagi.config.processes
        Array(protocols).map(&:to_sym).map do |protocol|
          instantiate_server(protocol, port, threads: threads, processes: processes, router: router)
        end
      end

      # Instantiates a server for the given protocol using ServerRegistry
      #
      # @param protocol [Symbol] Protocol identifier (:udp, :tcp, etc.)
      # @param port [Integer] Port to bind to
      # @param threads [Integer] Number of worker threads
      # @param processes [Integer] Number of worker processes (UDP only)
      # @param router [Router, CompositeRouter, nil] Custom router (uses global if nil)
      # @return [Server] Server instance
      def instantiate_server(protocol, port, threads:, processes:, router: nil)
        options = { port: port }
        options[:worker_threads] = threads
        options[:router] = router if router

        # UDP requires worker_processes, TCP doesn't use it
        options[:worker_processes] = processes if protocol == :udp
        Takagi.logger.debug("Instantiating server for #{protocol} on port #{port} with #{options}")
        ServerRegistry.build(protocol, **options)
      end

      # Runs servers (single or multi-protocol)
      #
      # @param servers [Array<Server>] Server instances to run
      def run_servers(servers)
        return servers.first.run! if servers.length == 1

        Takagi::Server::Multi.new(servers).run!
      end
    end
  end
end
