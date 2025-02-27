# frozen_string_literal: true

module Takagi
  class Initializer
    def self.run!
      load_initializers
    end

    def self.load_initializers
      Dir.glob("config/initializers/**/*.rb").each do |initializer|
        require_relative initializer
      end
    end
  end
end
