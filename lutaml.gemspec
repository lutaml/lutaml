require_relative "lib/lutaml/version"

Gem::Specification.new do |spec|
  spec.name          = "lutaml"
  spec.version       = Lutaml::VERSION
  spec.authors       = ["Ribose Inc."]
  spec.email         = ["open.source@ribose.com"]

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

  spec.required_ruby_version = ">= 3.2.0"

  spec.add_dependency "expressir", "~> 2.3"
  # TODO: remove once reline declares fiddle as a dependency
  # (fiddle was removed from Ruby 4.0 default gems, breaking reline on Windows)
  spec.add_dependency "fiddle"
  spec.add_dependency "lutaml-lml"
  spec.add_dependency "lutaml-uml"
  spec.metadata["rubygems_mfa_required"] = "true"
end
