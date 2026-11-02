# frozen_string_literal: true

require_relative "lib/lutaml/xsd/version"

Gem::Specification.new do |spec|
  spec.name = "lutaml-xsd"
  spec.version = Lutaml::Xsd::VERSION
  spec.authors = ["Ribose Inc."]
  spec.email = ["open.source@ribose.com"]

  spec.summary = "Library for XML Schema Definition (XSD) files"
  spec.description = "Parser and builder for XML Schema Definition (XSD) files."

  spec.homepage = "https://github.com/lutaml/expressir"
  spec.license = "BSD-2-Clause"

  spec.required_ruby_version = Gem::Requirement.new(">= 3.0.0")

  spec.bindir = "exe"
  spec.require_paths = ["lib"]
  spec.executables = ["lutaml-xsd"]

  spec.metadata["homepage_uri"] = spec.homepage
  spec.metadata["source_code_uri"] = spec.homepage
  spec.metadata["changelog_uri"] = "https://github.com/lutaml/lutaml-xsd/releases"
  spec.metadata["rubygems_mfa_required"] = "true"

  spec.files = Dir.chdir(File.expand_path(__dir__)) do
    `git ls-files -z`.split("\x0").reject do |f|
      f.match(%r{^(test|spec|features)/})
    end + Dir.glob("frontend/dist/*")
  end

  spec.add_dependency "liquid", ">= 4.0", "< 6.0"
  spec.add_dependency "lutaml-model", "~> 0.8.156"
  spec.add_dependency "lutaml-store", "~> 0.3"
  spec.add_dependency "moxml", "~> 0.6.0"
  spec.add_dependency "paint", "~> 2.3"
  spec.add_dependency "rng", "~> 0.3.9"
  spec.add_dependency "rubyzip", "~> 3.4"
  spec.add_dependency "table_tennis", "~> 0.0.7"
  spec.add_dependency "thor", "~> 1.0"
  spec.add_dependency "tty-prompt", "~> 0.23"
  spec.add_dependency "xsdvi"
end
