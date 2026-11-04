require "lutaml/model"
# Liquid is intentionally NOT required here: lutaml-model's Liquefiable
# lazily loads it on first #to_liquid (lutaml-model#800), keeping ~170ms
# off the boot of every consumer that never renders Liquid templates.

# ..........................................................
# https://bugs.ruby-lang.org/issues/19319
# The issue is that this bug is fixed for 3.1 and above,
# but not for 3.0 or 2.7, so we need a "safe" function
# ..........................................................
if RUBY_VERSION < "3.1"
  class String
    def safe_downcase
      each_char.map(&:downcase).join
    end
  end
else
  class String
    def safe_downcase
      downcase
    end
  end
end

module Expressir
  # Namespace modules - autoload loads the namespace file which contains
  # autoload definitions for classes within that namespace
  autoload :Config, "#{__dir__}/expressir/config"
  extend Config

  autoload :Version, "#{__dir__}/expressir/version"
  autoload :Mapping, "#{__dir__}/expressir/mapping"
  autoload :P21, "#{__dir__}/expressir/p21"
  autoload :P28, "#{__dir__}/expressir/p28"
  autoload :Receipt, "#{__dir__}/expressir/receipt"
  autoload :Reference, "#{__dir__}/expressir/reference"

  # Error classes — autoload the same errors.rb file from each name.
  # The first reference triggers the load; the file defines all 21 classes.
  autoload :Error, "#{__dir__}/expressir/errors"
  autoload :FileNotFoundError, "#{__dir__}/expressir/errors"
  autoload :ManifestNotFoundError, "#{__dir__}/expressir/errors"
  autoload :PackageNotFoundError, "#{__dir__}/expressir/errors"
  autoload :SchemaNotFoundError, "#{__dir__}/expressir/errors"
  autoload :UsageError, "#{__dir__}/expressir/errors"
  autoload :MissingRequiredArgumentError, "#{__dir__}/expressir/errors"
  autoload :InvalidOptionError, "#{__dir__}/expressir/errors"
  autoload :ValidationError, "#{__dir__}/expressir/errors"
  autoload :ManifestValidationError, "#{__dir__}/expressir/errors"
  autoload :SchemaValidationError, "#{__dir__}/expressir/errors"
  autoload :ReferentialIntegrityError, "#{__dir__}/expressir/errors"
  autoload :NoValidSchemaPathsError, "#{__dir__}/expressir/errors"
  autoload :CommandError, "#{__dir__}/expressir/errors"
  autoload :PackageBuildError, "#{__dir__}/expressir/errors"
  autoload :PackageReadError, "#{__dir__}/expressir/errors"
  autoload :PackageExtractError, "#{__dir__}/expressir/errors"
  autoload :PackageValidationError, "#{__dir__}/expressir/errors"
  autoload :PackageListError, "#{__dir__}/expressir/errors"
  autoload :PackageSearchError, "#{__dir__}/expressir/errors"
  autoload :PackageTreeError, "#{__dir__}/expressir/errors"

  # Backward-compatible top-level VERSION constant.
  # Expressir::VERSION is a string, which Ruby autoload cannot lazy-load
  # (autoload only works for module/class constants). The actual value
  # lives in Expressir::Version::VERSION, autoloaded on first reference.
  # This const_missing triggers the autoload when Expressir::VERSION is
  # referenced, then caches the result.
  def self.const_missing(name)
    return Version::VERSION if name == :VERSION

    super
  end

  autoload :Benchmark, "#{__dir__}/expressir/benchmark"
  autoload :Scoreboard, "#{__dir__}/expressir/scoreboard"
  autoload :Coverage, "#{__dir__}/expressir/coverage"

  autoload :Express, "#{__dir__}/expressir/express"
  autoload :Model, "#{__dir__}/expressir/model"
  autoload :Commands, "#{__dir__}/expressir/commands"
  autoload :Changes, "#{__dir__}/expressir/changes"
  autoload :Eval, "#{__dir__}/expressir/eval"
  autoload :Conformance, "#{__dir__}/expressir/conformance"
  autoload :Package, "#{__dir__}/expressir/package"
  autoload :Manifest, "#{__dir__}/expressir/manifest"
  autoload :Eengine, "#{__dir__}/expressir/eengine"
  autoload :Interop, "#{__dir__}/expressir/interop"
  autoload :Lsp, "#{__dir__}/expressir/lsp"
  autoload :SchemaManifest, "#{__dir__}/expressir/schema_manifest"
  autoload :SchemaManifestEntry, "#{__dir__}/expressir/schema_manifest_entry"

  # CLI is loaded last so that namespace autoloads are defined first
  # CLI uses Expressir::Commands::* which triggers autoload
  autoload :Cli, "#{__dir__}/expressir/cli"

  def self.root
    File.dirname(__dir__)
  end

  def self.root_path
    @root_path ||= Pathname.new(Expressir.root)
  end
end
