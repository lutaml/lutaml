# frozen_string_literal: true

require_relative "lib/lutaml/express/version"

Gem::Specification.new do |spec|
  spec.name          = "lutaml-express"
  spec.version       = Lutaml::Express::VERSION
  spec.authors       = ["Ribose Inc."]
  spec.email         = ["open.source@ribose.com'"]

  spec.summary       = "EXPRESS model module for LutaML."
  spec.description   = "EXPRESS model module for LutaML."
  spec.homepage      = "https://github.com/lutaml/lutaml-express"
  spec.license       = "MIT"

  spec.metadata["homepage_uri"] = spec.homepage
  spec.metadata["source_code_uri"] = spec.homepage
  spec.metadata["changelog_uri"] = "https://github.com/lutaml/lutaml-express/releases"

  spec.files         = `git ls-files`.split("\n")
  spec.test_files    = `git ls-files -- {spec}/*`.split("\n")

  spec.bindir        = "exe"
  spec.require_paths = ["lib"]

  spec.required_ruby_version = '>= 2.7.0'

  spec.add_runtime_dependency "expressir", "~> 1.2"

  spec.add_development_dependency "byebug"
  spec.add_development_dependency "nokogiri", "~> 1.10"
  spec.add_development_dependency "rubocop", "~> 0.54.0"
  spec.add_development_dependency "bundler", "~> 2.0"
  spec.add_development_dependency "rake", "~> 10.0"
  spec.add_development_dependency "rspec", "~> 3.0"
end
