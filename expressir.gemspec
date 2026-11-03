lib = File.expand_path("lib", __dir__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require "expressir/version"

Gem::Specification.new do |spec|
  spec.name = "expressir"
  spec.version = Expressir::Version::VERSION
  spec.authors = ["Ribose Inc."]
  spec.email = ["open.source@ribose.com"]

  spec.summary = "EXPRESS parser and toolkit for Ruby"
  spec.description = 'Expressir ("EXPRESS in Ruby") is a Ruby parser for EXPRESS and a set of tools for accessing EXPRESS data models.'

  spec.homepage = "https://github.com/lutaml/expressir"
  spec.license = "BSD-2-Clause"

  spec.bindir = "exe"
  spec.executables   = %w[expressir expressir-lsp]
  spec.require_paths = ["lib"]

  spec.metadata["homepage_uri"] = spec.homepage
  spec.metadata["source_code_uri"] = spec.homepage
  spec.metadata["changelog_uri"] = "https://github.com/lutaml/expressir/releases"
  spec.metadata["rubygems_mfa_required"] = "true"

  spec.required_ruby_version = Gem::Requirement.new(">= 3.2.0")
  # Source gem builds on the ruby platform; declaring it keeps
  # rake-compiler's `gem` task from rebuilding the extension for the
  # host ruby during cross builds (rb-sys then sees a windows
  # CARGO_BUILD_TARGET with linux headers and refuses).
  spec.platform = Gem::Platform::RUBY

  spec.files = Dir.chdir(File.expand_path(__dir__)) do
    `git ls-files -z`.split("\x0").reject do |f|
      f.match(%r{^(test|spec|features)/})
    end
  end

  # Build the Rust core extension at install time. extconf.rb fails
  # soft (dummy Makefile) wherever cargo is unavailable, so installs
  # without a Rust toolchain fall back to the pure-Ruby parser.
  spec.extensions = ["ext/expressir_core/extconf.rb"]
  spec.add_dependency "rb_sys", "~> 0.9.130"

  spec.add_dependency "base64", ">= 0.1.0"
  spec.add_dependency "benchmark"
  spec.add_dependency "benchmark-ips"
  spec.add_dependency "csv"
  spec.add_dependency "liquid", "~> 5"
  # 0.8.151 is the first lutaml-model whose moxml constraint (>= 0.5.139,
  # < 0.7) admits the moxml 0.6 line; earlier releases pin moxml
  # ~> 0.5.139 and cannot co-resolve with the moxml floor below.
  spec.add_dependency "lutaml-model", "~> 0.8.159"
  spec.add_dependency "moxml", "~> 0.6.0"
  spec.add_dependency "paint"
  spec.add_dependency "parsanol", "~> 1.3.130"
  spec.add_dependency "ruby-progressbar", "~> 1.11"
  spec.add_dependency "rubyzip", "~> 3.7"
  spec.add_dependency "table_tennis"
  spec.add_dependency "thor", "~> 1.0"
  # Native YAML/JSON engine (lutaml-model opt-in by bundle contents)
  spec.add_dependency "yeptris", "~> 0.6.1"
end
