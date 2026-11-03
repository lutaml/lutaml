# frozen_string_literal: true

require "thor"
require "fileutils"
require_relative "base_command"
require_relative "init_command"
require_relative "metadata_command"
require_relative "tree_command"

module Lutaml
  module Xsd
    module Commands
      # Package management commands
      # Handles build, validate, and info operations for .lxr packages
      class PackageCommand < Thor
        # Command aliases
        map "b" => :build
        map "v" => :validate
        map "i" => :info
        map "q" => :quick
        map "ab" => :auto_build
        map "init" => :init

        class_option :verbose,
                     type: :boolean,
                     default: false,
                     desc: "Enable verbose output"

        desc "init ENTRY_POINTS",
             "Initialize package with interactive dependency resolution"
        long_desc <<~DESC
          Start interactive package builder session.

          Analyzes entry point schemas, discovers dependencies, and guides you through
          dependency resolution with auto-detection and pattern suggestions.

          Examples:
            lutaml-xsd package init schema.xsd
            lutaml-xsd package init schema1.xsd schema2.xsd --search-paths "schemas/**"
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
          InitCommand.new(entry_points, options).run
        end

        desc "build CONFIG_FILE",
             "Build a schema repository package from YAML configuration"
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
        def build(config_file)
          BuildCommand.new(config_file, options).run
        end

        desc "validate PACKAGE_FILE", "Validate a schema repository package"
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
          ValidateCommand.new(package_file, options).run
        end

        desc "info PACKAGE_FILE", "Display package metadata and statistics"
        option :format,
               type: :string,
               default: "text",
               enum: %w[text json yaml],
               desc: "Output format"
        def info(package_file)
          InfoCommand.new(package_file, options).run
        end

        desc "quick CONFIG", "Quick build + validate + stats workflow"
        long_desc <<~DESC
          Build, validate, and show statistics in one command.

          This is a convenience command that runs:
          1. package build
          2. package validate
          3. stats show

          Examples:
            lutaml-xsd package quick config.yml
            lutaml-xsd package quick config.yml --no-validate
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
          QuickCommand.new(config_file, options).run
        end

        desc "auto_build CONFIG", "Auto-build with smart caching"
        long_desc <<~DESC
          Build package only if source config/schemas have changed.

          Checks modification times and skips rebuild if cache is fresh.

          Examples:
            lutaml-xsd package auto-build config.yml
            lutaml-xsd package auto-build config.yml --force
        DESC
        option :output, type: :string, aliases: "-o"
        option :force, type: :boolean, aliases: "-f", desc: "Force rebuild"
        option :xsd_mode, type: :string, default: "include_all"
        option :resolution_mode, type: :string, default: "resolved"
        option :serialization_format, type: :string, default: "marshal"
        option :name, type: :string
        option :version, type: :string
        option :description, type: :string
        def auto_build(config_file)
          AutoBuildCommand.new(config_file, options).run
        end

        desc "stats PACKAGE_FILE", "Display package statistics"
        long_desc <<~DESC
          Display comprehensive statistics for a schema repository package (.lxr file).

          The statistics include:
          - Total number of schemas parsed
          - Total number of types indexed
          - Types breakdown by category (complex, simple, element, attribute, etc.)
          - Total number of namespaces

          Examples:
            # Display statistics for a package
            lutaml-xsd package stats pkg/my_schemas.lxr

            # Display statistics in JSON format
            lutaml-xsd package stats pkg/my_schemas.lxr --format json

            # Display statistics with verbose output
            lutaml-xsd package stats pkg/my_schemas.lxr --verbose
        DESC
        option :format,
               type: :string,
               enum: %w[text json yaml],
               default: "text",
               desc: "Output format (text, json, yaml)"
        def stats(package_file)
          require_relative "stats_command"
          StatsCommand::ShowCommand.new(package_file, options).run
        end

        desc "schemas PACKAGE_FILE", "List XSD schemas in the package"
        long_desc <<~DESC
          Display all XSD schema files contained in a schema repository package.

          Shows information about each schema including filename, target namespace,
          number of elements, and number of types defined.

          Use --classify to categorize schemas by role and resolution status:
          - Entrypoint schemas: Explicitly loaded schemas
          - Dependency schemas: Discovered through imports/includes
          - Fully resolved: All references resolved within package
          - Partially resolved: Some unresolved references

          Examples:
            # List schemas in text format
            lutaml-xsd package schemas pkg/my_schemas.lxr

            # List schemas in JSON format
            lutaml-xsd package schemas pkg/my_schemas.lxr --format json

            # Classify schemas by role and status
            lutaml-xsd package schemas pkg/my_schemas.lxr --classify
        DESC
        option :format,
               type: :string,
               default: "text",
               enum: %w[text json yaml],
               desc: "Output format (text, json, yaml)"
        option :classify,
               type: :boolean,
               default: false,
               desc: "Classify schemas by role and resolution status"
        def schemas(package_file)
          SchemasCommand.new(package_file, options).run
        end

        desc "validate_resolution PACKAGE",
             "Validate all references are fully resolved"
        long_desc <<~DESC
          Validate that all type, element, attribute, and group references in the
          package are fully resolved (no external dependencies).

          A fully resolved package means:
          - All type references can be found
          - All element references can be found
          - All attribute references can be found
          - All group references can be found
          - No imports/includes point outside the package

          Examples:
            lutaml-xsd package validate-resolution schemas.lxr
            lutaml-xsd package validate-resolution schemas.lxr --strict
            lutaml-xsd package validate-resolution schemas.lxr --format json
        DESC
        option :strict, type: :boolean, desc: "Fail on warnings too"
        option :format,
               type: :string,
               default: "text",
               enum: %w[text json yaml],
               desc: "Output format"
        def validate_resolution(package_file)
          ValidateResolutionCommand.new(package_file, options).run
        end

        map "vr" => :validate_resolution

        desc "coverage PACKAGE", "Analyze schema coverage from entry points"
        long_desc <<~DESC
          Analyze which types are reachable from entry point types.
          Shows used vs unused types and coverage percentage.

          This is useful for understanding which types in a schema package are
          actually used when starting from specific entry points, helping to
          identify dead code or unused schema definitions.

          Examples:
            # Analyze coverage from Building and Road types
            lutaml-xsd package coverage schemas.lxr --entry "Building,Road,Bridge"

            # Analyze coverage with namespace-prefixed types
            lutaml-xsd package coverage schemas.lxr --entry "gml:Point,gml:LineString"

            # Output in JSON format
            lutaml-xsd package coverage schemas.lxr --entry "unitsml:UnitType" --format json
        DESC
        option :entry,
               type: :string,
               required: true,
               desc: "Comma-separated entry types (e.g., 'Type1,ns:Type2')"
        option :format,
               type: :string,
               default: "text",
               enum: %w[text json yaml],
               desc: "Output format"
        def coverage(package_path)
          require_relative "coverage_command"
          CoverageCommand.new(package_path, options).run
        end

        map "cov" => :coverage

        desc "verify PACKAGE", "Verify XSD specification compliance"
        long_desc <<~DESC
          Validate schemas against W3C XSD specification.

          Checks for:
          - Target namespace requirements
          - Element/attribute form defaults
          - Circular imports
          - Duplicate definitions
          - Schema location completeness
          - Namespace consistency

          Examples:
            lutaml-xsd package verify schemas.lxr
            lutaml-xsd package verify schemas.lxr --xsd-version 1.1
            lutaml-xsd package verify schemas.lxr --strict
            lutaml-xsd package verify schemas.lxr --format json
        DESC
        option :xsd_version,
               type: :string,
               default: "1.0",
               enum: %w[1.0 1.1],
               desc: "XSD version to validate against"
        option :strict,
               type: :boolean,
               desc: "Fail on warnings"
        option :format,
               type: :string,
               default: "text",
               enum: %w[text json yaml],
               desc: "Output format"
        def verify(package_path)
          require_relative "verify_command"
          VerifyCommand.new(package_path, options).run
        end

        desc "extract PACKAGE_FILE SCHEMA_NAME",
             "Extract a schema from the package"
        long_desc <<~DESC
          Extract a specific XSD schema file from a schema repository package.

          The SCHEMA_NAME can be either a full filename (e.g., "schema.xsd") or just
          the basename without extension (e.g., "schema").

          Examples:
            # Extract a schema to stdout
            lutaml-xsd package extract pkg/my_schemas.lxr unitsml-v1.0-csd04.xsd

            # Extract a schema to a file
            lutaml-xsd package extract pkg/my_schemas.lxr unitsml-v1.0-csd04.xsd -o /tmp/extracted.xsd

            # Extract using basename only
            lutaml-xsd package extract pkg/my_schemas.lxr unitsml-v1.0-csd04 -o /tmp/extracted.xsd
        DESC
        option :output,
               type: :string,
               aliases: "-o",
               desc: "Output file path (default: stdout)"
        def extract(package_file, schema_name)
          ExtractCommand.new(package_file, schema_name, options).run
        end

        desc "metadata SUBCOMMAND", "Manage package metadata"
        subcommand "metadata", Commands::MetadataCommand

        desc "tree PACKAGE_FILE", "Display package contents as colorized tree"
        long_desc <<~DESC
          Display all contents of an LXR package file in a colorized tree structure.

          Shows organized view of package contents including:
          - Metadata files
          - XSD schema files
          - Serialized schema data
          - Type indexes
          - Configuration mappings

          Examples:
            # Basic tree view
            lutaml-xsd package tree pkg/urban_function.lxr

            # With file sizes
            lutaml-xsd package tree pkg/urban_function.lxr --show-sizes

            # Without colors (for CI/logging)
            lutaml-xsd package tree pkg/urban_function.lxr --no-color

            # Flat list instead of tree
            lutaml-xsd package tree pkg/urban_function.lxr --format flat
        DESC
        option :show_sizes,
               type: :boolean,
               default: false,
               desc: "Show file sizes"
        option :no_color,
               type: :boolean,
               default: false,
               desc: "Disable colored output"
        option :format,
               type: :string,
               default: "tree",
               enum: %w[tree flat],
               desc: "Output format (tree or flat)"
        def tree(package_file)
          TreeCommand.new(package_file, options).run
        end

        # Build command implementation
        class BuildCommand < BaseCommand
          def initialize(config_file, options)
            super(options)
            @config_file = config_file
          end

          def run
            validate_config_file
            build_package
          end

          private

          def validate_config_file
            return if File.exist?(@config_file)

            error "Configuration file not found: #{@config_file}"
            raise CommandError
          end

          def build_package
            verbose_output "Loading repository configuration from: #{@config_file}"
            repository = SchemaRepository.from_yaml_file(@config_file)
            verbose_output "✓ Configuration loaded"
            verbose_output "  Files: #{(repository.files || []).size}"
            verbose_output "  Schema Location Mappings: #{(repository.schema_location_mappings || []).size}"
            verbose_output "  Namespace Mappings: #{(repository.namespace_mappings || []).size}"
            verbose_output ""

            verbose_output "Parsing and resolving schemas..."
            repository.parse.resolve
            verbose_output "✓ Schemas parsed and resolved"
            verbose_output ""

            output_path = determine_output_path(repository)
            FileUtils.mkdir_p(File.dirname(output_path))

            # Load full YAML to extract metadata section
            full_config = YAML.load_file(@config_file) || {}
            metadata_config = full_config["metadata"] || {}
            build_config = full_config["build"] || {}

            verbose_output "Creating package: #{output_path}"
            verbose_output "  XSD Mode: #{options[:xsd_mode] || build_config['xsd_mode'] || 'include_all'}"
            verbose_output "  Resolution Mode: #{options[:resolution_mode] || build_config['resolution_mode'] || 'resolved'}"
            verbose_output "  Serialization Format: #{options[:serialization_format] || build_config['serialization_format'] || 'marshal'}"

            xsd_mode = (options[:xsd_mode] || build_config["xsd_mode"] || "include_all").to_sym
            resolution_mode = (options[:resolution_mode] || build_config["resolution_mode"] || "resolved").to_sym
            serialization_format = (options[:serialization_format] || build_config["serialization_format"] || "marshal").to_sym

            package = repository.to_package(
              output_path,
              xsd_mode: xsd_mode,
              resolution_mode: resolution_mode,
              serialization_format: serialization_format,
              metadata: build_metadata(metadata_config),
            )

            output "✓ Package created: #{output_path}"
            output "  Size: #{File.size(output_path)} bytes"

            validate_package(package) if options[:validate]
          rescue StandardError => e
            error "Failed to build package: #{e.message}"
            verbose_output e.backtrace.join("\n") if verbose?
            raise CommandError
          end

          def determine_output_path(repository)
            return options[:output] if options[:output]

            # Use output_package from config if available
            return repository.output_package if repository.output_package

            # Use package name from options or derive from first file
            name = options[:name] || derive_name_from_repository(repository)
            File.expand_path("pkg/#{name}.lxr")
          end

          def derive_name_from_repository(repository)
            return "schema_repository" if repository.files.empty?

            File.basename(repository.files.first, ".*")
          end

          def build_metadata(metadata_config = {})
            metadata = {}
            # CLI options override config file
            metadata[:name] = options[:name] if options[:name]
            metadata[:version] = options[:version] if options[:version]
            if options[:description]
              metadata[:description] = options[:description]
            end
            metadata[:created_by] = "lutaml-xsd CLI"
            # Config file metadata
            metadata[:title] =
              metadata_config["title"] || metadata_config["name"]
            unless options[:description]
              metadata[:description] =
                metadata_config["description"]
            end
            metadata[:homepage] = metadata_config["homepage"]
            metadata[:repository] = metadata_config["repository"]
            metadata[:documentation] = metadata_config["documentation"]
            metadata[:license] = metadata_config["license"]
            metadata[:license_url] = metadata_config["license_url"]
            metadata[:authors] = metadata_config["authors"]
            metadata[:tags] = metadata_config["tags"]
            # Pass through appearance and links from config
            if full_config["appearance"]
              metadata[:appearance] =
                full_config["appearance"]
            end
            if metadata_config["links"]
              metadata[:links] =
                metadata_config["links"]
            end
            metadata
          end

          def full_config
            @full_config ||= YAML.load_file(@config_file) || {}
          end

          def validate_package(package)
            verbose_output ""
            verbose_output "Validating package..."
            validation = package.validate

            if validation.valid?
              output "✓ Package is valid"
            else
              error "Package validation failed"
              validation.errors.each { |err| error "  - #{err}" }
              raise CommandError if options[:strict]
            end

            return unless validation.warnings.any?

            output "Warnings:"
            validation.warnings.each { |warn| output "  - #{warn}" }
            raise CommandError if options[:strict]
          end
        end

        # Validate command implementation
        class ValidateCommand < BaseCommand
          def initialize(package_file, options)
            super(options)
            @package_file = package_file
          end

          def run
            validate_file_exists
            perform_validation
          end

          private

          def validate_file_exists
            return if File.exist?(@package_file)

            error "Package file not found: #{@package_file}"
            raise CommandError
          end

          def perform_validation
            verbose_output "Validating package: #{@package_file}"

            package = SchemaRepositoryPackage.new(@package_file)
            validation = package.validate

            format = options[:format] || "text"

            case format
            when "json", "yaml"
              output format_output(validation.to_h, format)
            else
              display_text_validation(validation)
            end

            raise CommandError if !validation.valid? || (options[:strict] && validation.warnings.any?)
          rescue StandardError => e
            error "Validation error: #{e.message}"
            verbose_output e.backtrace.join("\n") if verbose?
            raise CommandError
          end

          def display_text_validation(validation)
            if validation.valid?
              output "✓ Package is VALID"
            else
              output "✗ Package is INVALID"
            end

            if validation.errors.any?
              output ""
              output "Errors (#{validation.errors.size}):"
              validation.errors.each { |err| output "  - #{err}" }
            end

            if validation.warnings.any?
              output ""
              output "Warnings (#{validation.warnings.size}):"
              validation.warnings.each { |warn| output "  - #{warn}" }
            end

            return unless verbose? && validation.metadata

            output ""
            output "Metadata:"
            validation.metadata.each do |key, value|
              output "  #{key}: #{value.inspect}"
            end
          end
        end

        # Info command implementation
        class InfoCommand < BaseCommand
          def initialize(package_file, options)
            super(options)
            @package_file = package_file
          end

          def run
            validate_file_exists
            display_info
          end

          private

          def validate_file_exists
            return if File.exist?(@package_file)

            error "Package file not found: #{@package_file}"
            raise CommandError
          end

          def display_info
            verbose_output "Loading package metadata: #{@package_file}"

            package = SchemaRepositoryPackage.new(@package_file)
            validation = package.validate

            unless validation.valid?
              error "Cannot display info for invalid package"
              validation.errors.each { |err| error "  - #{err}" }
              raise CommandError
            end

            format = options[:format] || "text"

            case format
            when "json", "yaml"
              output format_output(validation.metadata, format)
            else
              display_text_info(validation.metadata)
            end
          rescue StandardError => e
            error "Failed to read package info: #{e.message}"
            verbose_output e.backtrace.join("\n") if verbose?
            raise CommandError
          end

          def display_text_info(metadata)
            output "Package: #{File.basename(@package_file)}"
            output "Size: #{File.size(@package_file)} bytes"
            output ""
            output "Metadata:"
            output "-" * 80

            metadata.each do |key, value|
              if value.is_a?(Array)
                output "#{key}: (#{value.size} items)"
                value.first(3).each { |item| output "  - #{item.inspect}" }
                output "  ..." if value.size > 3
              elsif value.is_a?(Hash)
                output "#{key}:"
                value.each { |k, v| output "  #{k}: #{v}" }
              else
                output "#{key}: #{value}"
              end
            end
          end
        end

        # Quick command implementation
        class QuickCommand < BaseCommand
          def initialize(config_file, options)
            super(options)
            @config_file = config_file
          end

          def run
            # Step 1: Build package
            output "═" * 80
            output "Step 1: Building package"
            output "═" * 80
            build_cmd = BuildCommand.new(@config_file, options)
            build_cmd.run
            output ""

            # Determine package path
            package_path = determine_package_path

            # Step 2: Validate (unless skipped)
            unless options[:no_validate]
              output "═" * 80
              output "Step 2: Validating package"
              output "═" * 80
              validate_options = options.dup
              validate_options[:format] = "text"
              validate_cmd = ValidateCommand.new(package_path, validate_options)
              validate_cmd.run
              output ""
            end

            # Step 3: Show stats (unless skipped)
            unless options[:no_stats]
              output "═" * 80
              output "Step 3: Package statistics"
              output "═" * 80
              require_relative "stats_command"
              stats_options = options.dup
              stats_options[:format] = "text"
              stats_cmd = StatsCommand::ShowCommand.new(
                package_path,
                stats_options,
              )
              stats_cmd.run
              output ""
            end

            output "═" * 80
            output "✓ Quick workflow completed successfully"
            output "═" * 80
          rescue StandardError => e
            error "Quick workflow failed: #{e.message}"
            verbose_output e.backtrace.join("\n") if verbose?
            raise CommandError
          end

          private

          def determine_package_path
            if options[:output]
              options[:output]
            else
              # Load config to determine default path
              repository = SchemaRepository.from_yaml_file(@config_file)
              name = options[:name] || derive_name_from_repository(repository)
              File.expand_path("pkg/#{name}.lxr")
            end
          end

          def derive_name_from_repository(repository)
            return "schema_repository" if repository.files.empty?

            File.basename(repository.files.first, ".*")
          end
        end

        # Auto-build command implementation
        class AutoBuildCommand < BaseCommand
          def initialize(config_file, options)
            super(options)
            @config_file = config_file
          end

          def run
            validate_config_file

            package_path = determine_package_path

            if should_rebuild?(package_path)
              verbose_output "Cache is stale or --force specified, rebuilding..."
              build_package
            else
              output "✓ Package is up-to-date: #{package_path}"
              output "  Use --force to rebuild anyway"
            end
          rescue StandardError => e
            error "Auto-build failed: #{e.message}"
            verbose_output e.backtrace.join("\n") if verbose?
            raise CommandError
          end

          private

          def validate_config_file
            return if File.exist?(@config_file)

            error "Configuration file not found: #{@config_file}"
            raise CommandError
          end

          def should_rebuild?(package_path)
            # Force rebuild if --force flag is set
            return true if options[:force]

            # Rebuild if package doesn't exist
            return true unless File.exist?(package_path)

            # Check if config file is newer than package
            config_mtime = File.mtime(@config_file)
            package_mtime = File.mtime(package_path)

            if config_mtime > package_mtime
              verbose_output "Config file modified: #{config_mtime}"
              return true
            end

            # Check if any referenced schema files are newer
            repository = SchemaRepository.from_yaml_file(@config_file)
            repository.files.each do |file|
              next unless File.exist?(file)

              file_mtime = File.mtime(file)
              if file_mtime > package_mtime
                verbose_output "Schema file modified: #{file} (#{file_mtime})"
                return true
              end
            end

            false
          end

          def determine_package_path
            if options[:output]
              options[:output]
            else
              repository = SchemaRepository.from_yaml_file(@config_file)
              name = options[:name] || derive_name_from_repository(repository)
              File.expand_path("pkg/#{name}.lxr")
            end
          end

          def derive_name_from_repository(repository)
            return "schema_repository" if repository.files.empty?

            File.basename(repository.files.first, ".*")
          end

          def build_package
            verbose_output "Building package from: #{@config_file}"
            build_cmd = BuildCommand.new(@config_file, options)
            build_cmd.run
          end
        end

        # Schemas command implementation
        class SchemasCommand < BaseCommand
          def initialize(package_file, options)
            super(options)
            @package_file = package_file
          end

          def run
            validate_file_exists

            if options[:classify]
              display_classification
            else
              list_schemas
            end
          end

          private

          def validate_file_exists
            return if File.exist?(@package_file)

            error "Package file not found: #{@package_file}"
            raise CommandError
          end

          def list_schemas
            verbose_output "Loading package: #{@package_file}"

            # Load package and get serialized schemas (already parsed!)
            package = SchemaRepositoryPackage.new(@package_file)
            package.load_repository

            # Get all schemas from global cache
            all_schemas = Lutaml::Xml::Schema::Xsd::Schema.processed_schemas

            schemas_info = all_schemas.map do |file_path, schema|
              {
                filename: File.basename(file_path),
                target_namespace: schema.target_namespace || "(no namespace)",
                elements: schema.element.size,
                total_types: schema.simple_type.size + schema.complex_type.size,
              }
            end

            format = options[:format] || "text"

            case format
            when "json", "yaml"
              output format_output(schemas_info, format)
            else
              display_text_list(schemas_info)
            end
          rescue StandardError => e
            error "Failed to list schemas: #{e.message}"
            verbose_output e.backtrace.join("\n") if verbose?
            raise CommandError
          end

          def display_text_list(schemas_info)
            require "table_tennis"

            # Build table data
            rows = schemas_info.map do |info|
              {
                uri: info[:target_namespace],
                file: info[:filename],
                elements: info[:elements],
                types: info[:total_types],
              }
            end

            # Use table-tennis with options
            table = TableTennis.new(rows,
                                    title: "SCHEMAS (#{rows.size} total)",
                                    zebra: true,
                                    columns: %i[uri file elements types],
                                    headers: {
                                      uri: "Namespace URI",
                                      file: "File Name",
                                      elements: "Elements",
                                      types: "Types",
                                    })

            output table
          end

          def display_classification
            verbose_output "Loading package and classifying schemas: #{@package_file}"

            # Load repository from package
            repository = SchemaRepository.from_package(@package_file)

            # Get classification
            classification = repository.classify_schemas

            format = options[:format] || "text"

            case format
            when "json", "yaml"
              # Convert SchemaClassificationInfo objects to hashes
              serializable = {
                entrypoint_schemas: classification[:entrypoint_schemas].map(&:to_h),
                dependency_schemas: classification[:dependency_schemas].map(&:to_h),
                fully_resolved: classification[:fully_resolved].map(&:to_h),
                partially_resolved: classification[:partially_resolved].map(&:to_h),
                summary: classification[:summary],
              }
              output format_output(serializable, format)
            else
              display_text_classification(classification)
            end
          rescue StandardError => e
            error "Failed to classify schemas: #{e.message}"
            verbose_output e.backtrace.join("\n") if verbose?
            raise CommandError
          end

          def display_text_classification(classification)
            require "table_tennis"

            output "Schema Classification"
            output "=" * 80
            output ""

            # Summary
            summary = classification[:summary]
            output "Summary:"
            output "  Total Schemas: #{summary[:total_schemas]}"
            output "  Entrypoint Schemas: #{summary[:entrypoint_count]}"
            output "  Dependency Schemas: #{summary[:dependency_count]}"
            output "  Fully Resolved: #{summary[:fully_resolved_count]}"
            output "  Partially Resolved: #{summary[:partially_resolved_count]}"
            output "  Resolution: #{summary[:resolution_percentage]}%"
            output ""

            # Entrypoint schemas
            if classification[:entrypoint_schemas].any?
              output "─" * 80
              output "Entrypoint Schemas (#{classification[:entrypoint_schemas].size})"
              output "─" * 80
              display_schema_table(classification[:entrypoint_schemas])
              output ""
            end

            # Dependency schemas
            if classification[:dependency_schemas].any?
              output "─" * 80
              output "Dependency Schemas (#{classification[:dependency_schemas].size})"
              output "─" * 80
              display_schema_table(classification[:dependency_schemas])
              output ""
            end

            # Fully resolved
            if classification[:fully_resolved].any?
              output "─" * 80
              output "Fully Resolved Schemas (#{classification[:fully_resolved].size})"
              output "─" * 80
              display_schema_table(classification[:fully_resolved])
              output ""
            end

            # Partially resolved
            if classification[:partially_resolved].any?
              output "─" * 80
              output "Partially Resolved Schemas (#{classification[:partially_resolved].size})"
              output "─" * 80
              display_schema_table(classification[:partially_resolved])
              output ""
            end

            output "=" * 80
          end

          def display_schema_table(schema_infos)
            table_data = schema_infos.map do |info|
              info_hash = info.to_h
              {
                "Filename" => info_hash[:filename],
                "Namespace" => truncate_namespace(info_hash[:namespace]),
                "Elements" => info_hash[:elements_count],
                "Types" => info_hash[:types_count],
                "Status" => info_hash[:resolution_status].to_s.gsub("_",
                                                                    " ").capitalize,
              }
            end

            table = TableTennis.new(table_data)
            output table
          end

          def truncate_namespace(namespace)
            return namespace if namespace.length <= 40

            "...#{namespace[-37..]}"
          end
        end

        # Extract command implementation
        class ExtractCommand < BaseCommand
          def initialize(package_file, schema_name, options)
            super(options)
            @package_file = package_file
            @schema_name = schema_name
          end

          def run
            validate_file_exists
            extract_schema
          end

          private

          def validate_file_exists
            return if File.exist?(@package_file)

            error "Package file not found: #{@package_file}"
            raise CommandError
          end

          def extract_schema
            verbose_output "Extracting schema: #{@schema_name}"

            content = nil
            found = false

            begin
              require "zip"
              Zip::File.open(@package_file) do |zipfile|
                # Normalize schema name - add .xsd if not present
                search_name = @schema_name.end_with?(".xsd") ? @schema_name : "#{@schema_name}.xsd"

                # Search for the schema file
                entry = zipfile.find_entry("schemas/#{search_name}")

                unless entry
                  error "Schema not found in package: #{search_name}"
                  error "Available schemas:"
                  zipfile.each do |e|
                    next unless e.name.start_with?("schemas/") && e.name.end_with?(".xsd")

                    error "  - #{File.basename(e.name)}"
                  end
                  raise CommandError
                end

                content = entry.get_input_stream.read
                found = true
              end
            rescue Zip::Error => e
              error "Failed to read package: #{e.message}"
              verbose_output e.backtrace.join("\n") if verbose?
              raise CommandError
            rescue StandardError => e
              error "Failed to extract schema: #{e.message}"
              verbose_output e.backtrace.join("\n") if verbose?
              raise CommandError
            end

            return unless found

            write_output(content)
            verbose_output "✓ Schema extracted successfully"
          end

          def write_output(content)
            if options[:output]
              # Write to file
              File.write(options[:output], content)
              output "Schema written to: #{options[:output]}"
            else
              # Write to stdout
              output content
            end
          end
        end

        # ValidateResolution command implementation
        class ValidateResolutionCommand < BaseCommand
          def initialize(package_file, options)
            super(options)
            @package_file = package_file
          end

          def run
            validate_file_exists
            perform_resolution_validation
          end

          private

          def validate_file_exists
            return if File.exist?(@package_file)

            error "Package file not found: #{@package_file}"
            raise CommandError
          end

          def perform_resolution_validation
            verbose_output "Loading package: #{@package_file}"

            # Load the repository from package
            repository = load_repository(@package_file)

            # Ensure it's resolved
            ensure_resolved(repository)

            verbose_output "Validating all references are fully resolved..."

            # Create validator and run validation
            require_relative "../package_validator"
            validator = PackageValidator.new(repository)
            result = validator.validate_full_resolution

            # Format and display results
            format = options[:format] || "text"

            case format
            when "json"
              output format_as_json(result)
            when "yaml"
              output format_as_yaml(result)
            else
              display_text_results(result)
            end

            # Exit with appropriate code
            exit_code = determine_exit_code(result)
            exit exit_code if exit_code.positive?
          rescue StandardError => e
            error "Resolution validation failed: #{e.message}"
            verbose_output e.backtrace.join("\n") if verbose?
            raise CommandError
          end

          def format_as_json(result)
            require "json"
            JSON.pretty_generate(result)
          end

          def format_as_yaml(result)
            require "yaml"
            result.to_yaml
          end

          def display_text_results(result)
            output "=" * 80
            output "Package Resolution Validation"
            output "=" * 80
            output ""

            # Overall status
            if result[:valid]
              output "✓ VALID - All references are fully resolved"
            else
              output "✗ INVALID - Unresolved references found"
            end
            output ""

            # Statistics
            stats = result[:statistics]
            output "Statistics:"
            output "  Types checked: #{stats[:types_checked]}"
            output "  Elements checked: #{stats[:elements_checked]}"
            output "  Attributes checked: #{stats[:attributes_checked]}"
            output "  Groups checked: #{stats[:groups_checked]}"
            output "  Attribute groups checked: #{stats[:attribute_groups_checked]}"
            output ""

            # Errors
            if result[:errors].any?
              output "Errors (#{result[:errors].size}):"
              output "-" * 80
              result[:errors].each_with_index do |err, idx|
                output "#{idx + 1}. #{err}"
              end
              output ""
            end

            # Warnings
            if result[:warnings].any?
              output "Warnings (#{result[:warnings].size}):"
              output "-" * 80
              result[:warnings].each_with_index do |warn, idx|
                output "#{idx + 1}. #{warn}"
              end
              output ""
            end

            # Summary
            output "=" * 80
            if result[:valid]
              output "✓ Package is fully resolved and ready for use"
            else
              output "✗ Package has unresolved references"
              output "  Fix the errors above to create a fully resolved package"
            end
            output "=" * 80
          end

          def determine_exit_code(result)
            # Exit with error if not valid
            return 1 unless result[:valid]

            # Exit with error if strict and has warnings
            return 1 if options[:strict] && result[:warnings].any?

            # Success
            0
          end
        end
      end
    end
  end
end
