# frozen_string_literal: true

require_relative "lib/lutaml/graphviz/version"

Gem::Specification.new do |spec|
  spec.name = "lutaml-graphviz"
  spec.version = Lutaml::Graphviz::VERSION
  spec.authors = ["Ribose Inc."]
  spec.email = ["open.source@ribose.com"]

  spec.summary = "Graphviz diagram rendering for LutaML models"
  spec.description = "Renders LutaML (LML) documents as Graphviz diagrams. " \
                     "Owns the ruby-graphviz dependency so the lutaml core " \
                     "gemspecs never carry an optional render toolchain."
  spec.homepage = "https://github.com/lutaml/lutaml-graphviz"
  spec.license = "MIT"

  spec.metadata = {
    "homepage_uri" => spec.homepage,
    "source_code_uri" => spec.homepage,
    "changelog_uri" => "#{spec.homepage}/releases",
    "rubygems_mfa_required" => "true"
  }

  spec.files = Dir.glob("lib/**/*.rb")
  spec.require_paths = ["lib"]
  spec.required_ruby_version = ">= 3.0"

  # Today the LML model/formatter base live in lutaml-lml; after the L3
  # absorption (lutaml/lutaml#231) this dependency becomes `lutaml`.
  spec.add_dependency "lutaml-lml", ">= 0.3.6"
  spec.add_dependency "ruby-graphviz"
end
