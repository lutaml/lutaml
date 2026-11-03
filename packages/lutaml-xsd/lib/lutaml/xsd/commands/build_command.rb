# frozen_string_literal: true

require "thor"
require_relative "base_command"

module Lutaml
  module Xsd
    module Commands
      # Package creation commands (MECE category)
      # Handles all package building and initialization operations
      class BuildCommand < Thor
        class_option :verbose,
                     type: :boolean,
                     default: false,
                     desc: "Enable verbose output"

        desc "from-config CONFIG", "Build package from YAML configuration"
        long_desc <<~DESC
          Build a schema repository package from a YAML configuration file.

          Examples:
            # Basic build
            lutaml-xsd build from-config config.yml

            # Build with custom output path
            lutaml-xsd build from-config config.yml -o pkg/my-schemas.lxr

            # Build with validation
            lutaml-xsd build from-config config.yml --validate

            # Build with custom serialization format
            lutaml-xsd build from-config config.yml --serialization-format json
        DESC
        option :output,
               type: :string,
               aliases: "-o",
               desc: "Output package path (default: pkg/<name>.lxr)"
        option :xsd_mode,
               type: :string,
               default: "include_all",
               enum: %w[include_all allow_external],
               desc: "XSD bundling mode"
        option :resolution_mode,
               type: :string,
               default: "resolved",
               enum: %w[resolved bare],
               desc: "Resolution mode"
        option :serialization_format,
               type: :string,
               default: "marshal",
               enum: %w[marshal json yaml parse],
               desc: "Serialization format"
        option :name,
               type: :string,
               desc: "Package name"
        option :version,
               type: :string,
               desc: "Package version"
        option :description,
               type: :string,
               desc: "Package description"
        option :validate,
               type: :boolean,
               default: false,
               desc: "Validate package after building"
        def from_config(config_file)
          require_relative "package_command"
          PackageCommand::BuildCommand.new(config_file, options).run
        end

        desc "init ENTRY_POINTS", "Interactive package initialization"
        long_desc <<~DESC
          Start interactive package builder session.

          Analyzes entry point schemas, discovers dependencies, and guides you through
          dependency resolution with auto-detection and pattern suggestions.

          Examples:
            # Initialize from single schema
            lutaml-xsd build init schema.xsd

            # Initialize from multiple schemas
            lutaml-xsd build init schema1.xsd schema2.xsd

            # With custom search paths
            lutaml-xsd build init schema.xsd --search-paths "schemas/**"

            # Resume previous session
            lutaml-xsd build init schema.xsd --resume
        DESC
        option :search_paths,
               type: :array,
               desc: "Directories to search for schemas"
        option :output,
               type: :string,
               default: "repository.yml",
               desc: "Configuration file path"
        option :local,
               type: :boolean,
               desc: "Never fetch from URLs"
        option :no_fetch,
               type: :boolean,
               desc: "Disable automatic URL fetching"
        option :fetch_timeout,
               type: :numeric,
               default: 30,
               desc: "Timeout for URL downloads (seconds)"
        option :resume,
               type: :boolean,
               desc: "Resume previous session"
        def init(*entry_points)
          require_relative "init_command"
          InitCommand.new(entry_points, options).run
        end

        desc "quick CONFIG", "Quick build + validate + stats workflow"
        long_desc <<~DESC
          Build, validate, and show statistics in one command.

          This is a convenience command that runs:
          1. build from-config
          2. pkg validate (unless --no-validate)
          3. pkg stats (unless --no-stats)

          Examples:
            # Quick workflow
            lutaml-xsd build quick config.yml

            # Skip validation step
            lutaml-xsd build quick config.yml --no-validate

            # Skip stats display
            lutaml-xsd build quick config.yml --no-stats
        DESC
        option :output, type: :string, aliases: "-o", desc: "Output path"
        option :no_validate, type: :boolean, desc: "Skip validation step"
        option :no_stats, type: :boolean, desc: "Skip statistics display"
        option :xsd_mode, type: :string, default: "include_all"
        option :resolution_mode, type: :string, default: "resolved"
        option :serialization_format, type: :string, default: "marshal"
        option :name, type: :string
        option :version, type: :string
        option :description, type: :string
        def quick(config_file)
          require_relative "package_command"
          PackageCommand::QuickCommand.new(config_file, options).run
        end

        desc "auto CONFIG", "Auto-build with smart caching"
        long_desc <<~DESC
          Build package only if source config/schemas have changed.

          Checks modification times and skips rebuild if cache is fresh.

          Examples:
            # Auto-build (skips if up-to-date)
            lutaml-xsd build auto config.yml

            # Force rebuild
            lutaml-xsd build auto config.yml --force
        DESC
        option :output, type: :string, aliases: "-o"
        option :force, type: :boolean, aliases: "-f", desc: "Force rebuild"
        option :xsd_mode, type: :string, default: "include_all"
        option :resolution_mode, type: :string, default: "resolved"
        option :serialization_format, type: :string, default: "marshal"
        option :name, type: :string
        option :version, type: :string
        option :description, type: :string
        def auto(config_file)
          require_relative "package_command"
          PackageCommand::AutoBuildCommand.new(config_file, options).run
        end

        desc "validate PACKAGE", "Validate a schema repository package"
        long_desc <<~DESC
          Validate a schema repository package for correctness and completeness.

          Examples:
            # Basic validation
            lutaml-xsd build validate pkg/my_schemas.lxr

            # Strict mode (fail on warnings)
            lutaml-xsd build validate pkg/my_schemas.lxr --strict

            # Output as JSON
            lutaml-xsd build validate pkg/my_schemas.lxr --format json
        DESC
        option :format,
               type: :string,
               default: "text",
               enum: %w[text json yaml],
               desc: "Output format"
        option :strict,
               type: :boolean,
               default: false,
               desc: "Fail on warnings"
        def validate(package_file)
          require_relative "package_command"
          PackageCommand::ValidateCommand.new(package_file, options).run
        end

        desc "validate-resolution PACKAGE",
             "Validate all references are fully resolved"
        long_desc <<~DESC
          Validate that all type, element, attribute, and group references in the
          package are fully resolved (no external dependencies).

          Examples:
            # Validate resolution
            lutaml-xsd build validate-resolution schemas.lxr

            # Strict mode
            lutaml-xsd build validate-resolution schemas.lxr --strict

            # Output as JSON
            lutaml-xsd build validate-resolution schemas.lxr --format json
        DESC
        option :strict, type: :boolean, desc: "Fail on warnings too"
        option :format,
               type: :string,
               default: "text",
               enum: %w[text json yaml],
               desc: "Output format"
        def validate_resolution(package_file)
          require_relative "package_command"
          PackageCommand::ValidateResolutionCommand.new(package_file,
                                                        options).run
        end

        # Command aliases
        map "vr" => :validate_resolution
        map "ab" => :auto
        map "q" => :quick
      end
    end
  end
end
