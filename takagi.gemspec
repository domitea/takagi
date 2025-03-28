# frozen_string_literal: true

require_relative 'lib/takagi/version'

Gem::Specification.new do |spec|
  spec.name = 'takagi'
  spec.version = Takagi::VERSION
  spec.authors = ['Dominik Matoulek']
  spec.email = ['domitea@gmail.com']

  spec.summary = 'Lightweight CoAP framework for Ruby'
  spec.description = 'Sinatra-like framework for CoAP and IoT messaging.'
  spec.homepage = 'https://github.com/domitea/takagi'
  spec.license = 'MIT'
  spec.required_ruby_version = '>= 3.0.0'

  spec.metadata['allowed_push_host'] ||= 'https://rubygems.org'

  spec.metadata['homepage_uri'] = spec.homepage
  spec.metadata['source_code_uri'] = 'https://github.com/domitea/takagi'
  spec.metadata['changelog_uri'] = 'https://github.com/domitea/takagi/CHANGELOG.md'

  # Specify which files should be added to the gem when it is released.
  # The `git ls-files -z` loads the files in the RubyGem that have been added into git.
  spec.files = Dir.chdir(__dir__) do
    `git ls-files -z`.split("\x0").reject do |f|
      (File.expand_path(f) == __FILE__) ||
        f.start_with?(*%w[bin/ test/ spec/ features/ .git .github appveyor Gemfile])
    end
  end
  spec.bindir = 'exe'
  spec.executables = spec.files.grep(%r{\Aexe/}) { |f| File.basename(f) }
  spec.require_paths = ['lib']

  # Uncomment to register a new dependency of your gem
  # spec.add_dependency "example-gem", "~> 1.0"
  spec.add_dependency 'rack'
  spec.add_dependency 'zeitwerk'

  spec.add_development_dependency 'rspec'

  # For more information and examples about making a new gem, check out our
  # guide at: https://bundler.io/guides/creating_gem.html
  spec.metadata['rubygems_mfa_required'] = 'true'
end
