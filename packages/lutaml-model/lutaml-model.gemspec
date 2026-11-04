# frozen_string_literal: true

require_relative "lib/lutaml_model_shim/version"

Gem::Specification.new do |spec|
  spec.name = "lutaml-model"
  spec.version = LutamlModelShim::VERSION
  spec.authors = ["Ribose Inc."]
  spec.email = ["open.source@ribose.com"]

  spec.summary = "Transitional alias of lutaml (the lutaml-model runtime)"
  spec.description = <<~DESCRIPTION
    The lutaml-model runtime now ships in the `lutaml` gem. This gem only
    depends on it so `require "lutaml-model"` keeps working for one
    deprecation window; depend on `lutaml` directly.
  DESCRIPTION

  spec.homepage = "https://github.com/lutaml/lutaml"
  spec.license = "BSD-2-Clause"

  spec.bindir = "exe"
  spec.require_paths = ["lib"]
  spec.required_ruby_version = Gem::Requirement.new(">= 3.2.0")

  spec.files = Dir.chdir(File.expand_path(__dir__)) do
    Dir["lib/lutaml-model.rb", "lib/lutaml_model_shim/**/*.rb", "exe/*",
        "LICENSE.md", "README.adoc"]
  end
  spec.executables = ["lutaml-model"]

  spec.add_dependency "lutaml", ">= 0.11.7"

  spec.metadata["rubygems_mfa_required"] = "true"
end
