# frozen_string_literal: true

module Takagi
  module Server
    # Helper class to run multiple servers concurrently
    class Multi
      def initialize(servers)
        @servers = servers
        @threads = []
      end

      def run!
        trap('INT') { shutdown! }
        @threads = @servers.map { |srv| Thread.new { srv.run! } }
        @threads.each(&:join)
      end

      def shutdown!
        @servers.each(&:shutdown!)
        @threads.each(&:join)
      end
    end
  end
end
