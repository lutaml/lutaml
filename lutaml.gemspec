require_relative "lib/lutaml/version"

Gem::Specification.new do |spec|
  spec.name          = "lutaml"
  spec.version       = Lutaml::VERSION
  spec.authors       = ["Ribose Inc."]
  spec.email         = ["open.source@ribose.com'"]

  spec.summary       = "LutaML: data models in textual form"
  spec.description   = "LutaML: data models in textual form"
  spec.homepage      = "https://github.com/lutaml/lutaml"
  spec.license       = "MIT"

  spec.metadata["homepage_uri"] = spec.homepage
  spec.metadata["source_code_uri"] = spec.homepage
  spec.metadata["changelog_uri"] = "https://github.com/lutaml/lutaml/releases"

  # Specify which files should be added to the gem when it is released.
  # The `git ls-files -z` loads the files in the RubyGem
  # that have been added into git.
  spec.files = Dir.chdir(File.expand_path(__dir__)) do
    `git ls-files -z`
      .split("\x0")
      .reject { |f| f.match(%r{^(test|spec|features)/}) }
  end
  spec.bindir        = "exe"
  spec.executables   = spec.files.grep(%r{^exe/}) { |f| File.basename(f) }
  spec.require_paths = ["lib"]

  spec.required_ruby_version = ">= 2.7.0" # rubocop:disable Gemspec/RequiredRubyVersion

  spec.add_dependency "expressir", "~> 2.1.0"
  spec.add_dependency "hashie", "~> 4.1.0"
  spec.add_dependency "htmlentities"
  spec.add_dependency "liquid"
  spec.add_dependency "lutaml-model"
  spec.add_dependency "lutaml-path"
  spec.add_dependency "lutaml-xsd"
  spec.add_dependency "nokogiri", "~> 1.10"
  spec.add_dependency "parslet", "~> 2.0.0"
  spec.add_dependency "ruby-graphviz", "~> 1.2"
  spec.add_dependency "thor", "~> 1.0"
  spec.add_dependency "xmi", "~> 0.3.20"
  spec.metadata["rubygems_mfa_required"] = "true"
end
