# frozen_string_literal: true

module Takagi
  # Let's do some initialization
  class Initializer
    # Runs the initialization logic (e.g., loading configurations, setting up databases)
    def self.run!
      load_initializers
    end

    def self.load_initializers
      Dir.glob(File.expand_path('config/initializers/**/*.rb', __dir__)).each do |initializer|
        require initializer
      end
    end
  end
end
