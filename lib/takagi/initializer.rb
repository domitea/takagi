# frozen_string_literal: true

module Takagi
  class Initializer
    def self.run!
      load_initializers
    end

    def self.load_initializers
      Dir.glob(File.expand_path("config/initializers/**/*.rb", __dir__)).each do |initializer|
        require initializer
      end
    end
  end
end
