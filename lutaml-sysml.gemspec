require_relative 'lib/lutaml/sysml/version'

Gem::Specification.new do |spec|
  spec.name          = "lutaml-sysml"
  spec.version       = Lutaml::Sysml::VERSION
  spec.authors       = ["Ribose Inc."]
  spec.email         = ["open.source@ribose.com'"]

  spec.summary       = "SysML model module for LutaML."
  spec.description   = "SysML model module for LutaML."
  spec.homepage      = "https://github.com/lutaml/lutaml-sysml"
  spec.license       = "MIT"

  spec.metadata["homepage_uri"] = spec.homepage
  spec.metadata["source_code_uri"] = spec.homepage
  spec.metadata["changelog_uri"] = "https://github.com/lutaml/lutaml-sysml/releases"

  spec.files         = `git ls-files`.split("\n")
  spec.test_files    = `git ls-files -- {spec}/*`.split("\n")

  spec.bindir        = "exe"
  spec.require_paths = ["lib"]
  spec.executables   = %w[lutaml-sysml]

  spec.required_ruby_version = '>= 2.7.0'

  spec.add_runtime_dependency "thor", "~> 1.0"
  # spec.add_runtime_dependency "lutaml-uml"
  spec.add_development_dependency "lutaml-uml"
  spec.add_development_dependency "nokogiri", "~> 1.10"

  spec.add_development_dependency "bundler", "~> 2.0"
  spec.add_development_dependency "pry", "~> 0.12.2"
  spec.add_development_dependency "rake", "~> 10.0"
  spec.add_development_dependency "rspec", "~> 3.0"
end
