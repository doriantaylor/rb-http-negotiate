# -*- mode: enh-ruby -*-
require_relative 'lib/http/negotiate/version'

Gem::Specification.new do |spec|
  spec.name          = 'http-negotiate'
  spec.version       = HTTP::Negotiate::VERSION
  spec.authors       = ['Dorian Taylor']
  spec.email         = ['code@doriantaylor.com']
  spec.license       = 'Apache-2.0'
  spec.homepage      = 'https://github.com/doriantaylor/rb-http-negotiate'
  spec.summary       = 'An implementation of Gisle Aas\'s HTTP::Negotiate'

  spec.metadata['homepage_uri']    = spec.homepage
  spec.metadata['source_code_uri'] = spec.homepage

  # Specify which files should be added to the gem when it is
  # released. The `git ls-files -z` loads the files in the RubyGem
  # that have been added into git.
  spec.files         = Dir.chdir(File.expand_path('..', __FILE__)) do
    `git ls-files -z`.split("\x0").reject do |f|
      f.match(%r{^(test|spec|features)/})
    end
  end

  spec.bindir        = "exe"
  spec.executables   = spec.files.grep(%r{^exe/}) { |f| File.basename(f) }
  spec.require_paths = ["lib"]

  spec.required_ruby_version = Gem::Requirement.new(">= 2.4.0")

  # dev/test dependencies
  spec.add_development_dependency 'bundler', '~> 2.2'
  spec.add_development_dependency 'rake',    '~> 13.0'
  spec.add_development_dependency 'rspec',   '~> 3.12'
end
