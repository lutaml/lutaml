# frozen_string_literal: true

require "thor"
require "json"
require "yaml"
require "pathname"

module Expressir
  module Commands
    # Package management CLI commands
    # Handles LER package creation, inspection, validation, and extraction
    class Package < Thor
      include Thor::Actions

      # Allow options to be set for testing
      attr_accessor :options

      def initialize(options_or_args = [], *args, **kwargs)
        # Check if first argument is options hash (for testing)
        if options_or_args.is_a?(Hash) && args.empty? && kwargs.empty?
          # Direct options passed for testing - don't initialize Thor
          @options = options_or_args
        else
          # Normal Thor initialization
          super
          @options ||= {}
        end
      end

      desc "build ROOT_SCHEMA OUTPUT",
           "Build LER package from schema with dependency resolution"
      long_desc <<~DESC
        Build an LER package from a root schema file or manifest.

        Two modes:
        1. Auto-resolution: Parses root schema and resolves dependencies
        2. Manifest-based: Uses pre-generated manifest file

        Manifest Verification (manifest-based mode only):
        By default, manifests are verified for referential integrity before building.
        This ensures all USE FROM and REFERENCE FROM declarations can be resolved.

        Use --skip-verify to bypass verification (may result in incomplete packages).
        Warning: Skipping verification may produce packages with missing dependencies
        that are not fully internally consistent.

        Options match the Ruby API Repository#export_to_package method:
        - express_mode: How to bundle EXPRESS files
        - resolution_mode: Whether to pre-serialize schemas
        - serialization_format: Format for serialized data
        - validate: Run validation before packaging
        - base_dirs: Base directories for schema resolution (auto-resolution only)
        - manifest: Use pre-generated manifest file (skips dependency resolution)
        - skip_verify: Skip manifest verification (manifest-based only)

        Example (auto-resolution):
          expressir package build schemas/activity/mim.exp activity.ler \\
            --name "Activity Module" \\
            --version "1.0" \\
            --validate

        Example (manifest-based with verification):
          expressir package build --manifest activity_manifest.yaml activity.ler \\
            --validate

        Example (manifest-based, skip verification):
          expressir package build --manifest activity_manifest.yaml activity.ler \\
            --skip-verify
      DESC
      option :name, type: :string, desc: "Package name for metadata"
      option :version, type: :string, desc: "Package version for metadata",
                       default: "1.0.0"
      option :description, type: :string,
                           desc: "Package description for metadata"
      option :express_mode, type: :string, default: "include_all",
                            enum: ["include_all", "allow_external"],
                            desc: "EXPRESS bundling mode"
      option :resolution_mode, type: :string, default: "resolved",
                               enum: ["resolved", "bare"],
                               desc: "Schema resolution mode"
      option :serialization_format, type: :string, default: "marshal",
                                    enum: ["marshal", "json", "yaml"],
                                    desc: "Serialization format for resolved mode"
      option :validate, type: :boolean, default: true,
                        desc: "Validate repository before packaging"
      option :base_dirs, type: :string,
                         desc: "Comma-separated list of base directories for schema resolution (auto-resolution only)"
      option :manifest, type: :string,
                        desc: "Use pre-generated manifest file (skips dependency resolution)"
      option :skip_verify, type: :boolean, default: false,
                           desc: "Skip manifest verification (may result in incomplete packages)"
      option :verbose, type: :boolean, default: false,
                       desc: "Enable verbose output"
      option :max_processes, type: :numeric, default: 1,
                             desc: "Parallel parse workers for schema loading (1 = sequential)"
      def build(root_schema = nil, output = nil)
        schema_files, output = resolve_schema_files(root_schema, output)
        repo = Expressir::Model::Repository.from_files(schema_files,
                                                       max_processes: options[:max_processes])
        validate_repository(repo) if should_validate?
        create_package(repo, output)
      rescue Expressir::Error
        raise
      rescue StandardError => e
        raise Expressir::PackageBuildError.new(
          "Error building package: #{e.message}",
          command_name: "package build",
        )
      end

      private

      def resolve_schema_files(root_schema, output)
        if options[:manifest]
          [resolve_from_manifest(output), output || root_schema]
        else
          [resolve_from_auto_resolution(root_schema), output]
        end
      end

      def resolve_from_manifest(output)
        raise Expressir::ManifestNotFoundError.new(options[:manifest]) unless File.exist?(options[:manifest])

        unless output || root_schema_arg
          raise Expressir::MissingRequiredArgumentError.new(
            "OUTPUT path is required",
            usage_hint: "expressir package build --manifest MANIFEST.yaml OUTPUT.ler",
          )
        end

        say "Building LER package from manifest #{options[:manifest]}..." if options[:verbose]

        manifest = Expressir::SchemaManifest.from_file(options[:manifest])
        manifest_data = YAML.load_file(options[:manifest])
        manifest_dir = File.dirname(File.expand_path(options[:manifest]))

        verify_manifest(manifest) unless options[:skip_verify]
        collect_manifest_paths(manifest_data, manifest_dir)
      end

      def verify_manifest(manifest)
        say "Verifying manifest integrity..."
        validator = Expressir::Manifest::Validator.new(manifest, options.merge(verbose: true))

        file_errors = validator.validate_file_existence
        unless file_errors.empty?
          raise Expressir::ManifestValidationError.new(
            "Manifest validation failed", errors: file_errors.map { |e| e[:message] }
          )
        end

        reference_errors = validator.validate_referential_integrity
        unless reference_errors.empty?
          raise Expressir::ReferentialIntegrityError.new(
            reference_errors, message: "Manifest has unresolved dependencies"
          )
        end

        say "✓ Manifest verified", :green
      end

      def collect_manifest_paths(manifest_data, manifest_dir)
        errors = []
        warnings = []
        paths = []

        manifest_data["schemas"].each do |schema_id, schema_data|
          schema_path = schema_data["path"]
          if schema_path.nil? || schema_path.empty?
            warnings << "Schema '#{schema_id}' has no path specified"
            next
          end

          full_path = Pathname.new(schema_path).absolute? ? schema_path : File.expand_path(schema_path, manifest_dir)
          if File.exist?(full_path)
            paths << full_path
          else
            errors << "Schema file not found: #{full_path} (#{schema_id})"
          end
        end

        raise Expressir::ManifestValidationError.new("Manifest validation failed", errors: errors) unless errors.empty?

        say "Warnings:" if options[:verbose] && warnings.any?
        warnings.each { |w| say "  - #{w}", :yellow } if options[:verbose] && warnings.any?
        say "  Using #{paths.size} schema(s) from manifest" if options[:verbose]
        paths
      end

      def resolve_from_auto_resolution(root_schema)
        unless root_schema
          raise Expressir::MissingRequiredArgumentError.new(
            "ROOT_SCHEMA is required when not using --manifest",
            usage_hint: "expressir package build ROOT_SCHEMA OUTPUT.ler",
          )
        end

        say "Building LER package from #{root_schema}..." if options[:verbose]
        say "Resolving dependencies..." if options[:verbose]

        base_dirs = options[:base_dirs] ? options[:base_dirs].split(",").map(&:strip) : [File.dirname(File.expand_path(root_schema))]
        if options[:verbose] && base_dirs.size == 1
          say "  Using base directory: #{base_dirs.first}"
          say "  Tip: Use --base-dirs to specify additional search paths for dependencies"
        end

        resolver = Expressir::Model::DependencyResolver.new(base_dirs: base_dirs, verbose: options[:verbose])
        resolved = resolver.resolve_dependencies(root_schema)
        say "  Found #{resolved.size} schema(s)" if options[:verbose]
        resolved
      end

      def should_validate?
        return false if options[:manifest] && options[:skip_verify]

        options[:validate]
      end

      def validate_repository(repo)
        say "Validating repository..." if options[:verbose]
        validation = repo.validate
        return if validation[:valid?]

        formatted_errors = (validation[:errors] || []).map do |e|
          next e.to_s unless e.is_a?(Hash)

          msg = e[:message] || "Unknown error"
          type = e[:type] ? "[#{e[:type]}] " : ""
          schema = e[:schema] ? " (schema: #{e[:schema]})" : ""
          ref = e[:referenced_schema] ? " (referenced: #{e[:referenced_schema]})" : ""
          iface = e[:interface_type] ? " (interface: #{e[:interface_type]})" : ""
          "#{type}#{msg}#{schema}#{ref}#{iface}"
        end
        raise Expressir::SchemaValidationError.new("Repository validation failed", errors: formatted_errors)
      end

      def create_package(repo, output)
        say "Creating package..." if options[:verbose]
        repo.export_to_package(output, build_package_options)
        say "✓ Package created: #{output}", :green
        say "  Schemas: #{repo.schemas.size}", :green if options[:verbose]
      end

      public

      desc "info PACKAGE", "Display package metadata and statistics"
      long_desc <<~DESC
        Display comprehensive information about an LER package including metadata,
        statistics, and configuration.

        Output formats:
        - text: Human-readable formatted output (default)
        - json: Machine-readable JSON
        - yaml: YAML format

        Example:
          expressir package info activity.ler
          expressir package info activity.ler --format json
      DESC
      option :format, type: :string, default: "text",
                      enum: ["text", "json", "yaml"],
                      desc: "Output format"
      def info(package_path)
        repo = load_package(package_path)
        metadata = load_package_metadata(package_path)

        case options[:format]
        when "json"
          output_json_info(metadata, repo)
        when "yaml"
          output_yaml_info(metadata, repo)
        else
          output_text_info(metadata, repo)
        end
      rescue Expressir::Error
        raise # Re-raise Expressir errors
      rescue StandardError => e
        raise Expressir::PackageReadError.new(
          "Error reading package info: #{e.message}",
          command_name: "package info",
        )
      end

      desc "validate PACKAGE", "Validate package structure and integrity"
      long_desc <<~DESC
        Validate an LER package structure, metadata, and repository consistency.

        Checks performed:
        - Package file integrity
        - Metadata validation
        - Schema completeness
        - Reference resolution
        - Optional interface validation
        - Optional strict mode for enhanced validation

        Validation options:
        - --strict: Enable strict validation (unused schemas become warnings)
        - --check-interfaces: Perform detailed interface validation
        - --check-completeness: Check for schema completeness
        - --check-duplicates: Check for duplicate interface aliases
        - --check-self-references: Check for self-referencing interfaces
        - --detailed: Show detailed validation reports with fix suggestions

        Example:
          expressir package validate activity.ler
          expressir package validate activity.ler --strict
          expressir package validate activity.ler --check-interfaces --detailed
          expressir package validate activity.ler --strict --check-completeness --check-interfaces
      DESC
      option :strict, type: :boolean, default: false,
                      desc: "Enable strict validation (unused schemas)"
      option :check_interfaces, type: :boolean, default: true,
                                desc: "Perform detailed interface validation"
      option :check_completeness, type: :boolean, default: false,
                                  desc: "Check for schema completeness"
      option :check_duplicates, type: :boolean, default: false,
                                desc: "Check for duplicate interface aliases"
      option :check_self_references, type: :boolean, default: false,
                                     desc: "Check for self-referencing interfaces"
      option :detailed, type: :boolean, default: false,
                        desc: "Show detailed validation reports with fix suggestions"
      option :format, type: :string, default: "text",
                      enum: ["text", "json", "yaml"],
                      desc: "Output format"
      def validate(package_path)
        repo = load_package(package_path)
        validation = repo.validate(
          strict: options[:strict],
        )

        case options[:format]
        when "json"
          output_json_validation(validation)
        when "yaml"
          output_yaml_validation(validation)
        else
          output_text_validation(validation)
        end

        unless validation[:valid?]
          raise Expressir::PackageValidationError.new(
            "Package validation failed",
            errors: validation[:errors] || [],
          )
        end
      rescue Expressir::Error
        raise # Re-raise Expressir errors
      rescue StandardError => e
        raise Expressir::PackageValidationError.new(
          "Error validating package: #{e.message}",
          command_name: "package validate",
        )
      end

      desc "extract PACKAGE", "Extract package contents to directory"
      long_desc <<~DESC
        Extract all contents of an LER package to a specified directory.

        Extracts:
        - Metadata file
        - EXPRESS schema files
        - Serialized repository (if present)
        - Index files
        - Manifest

        Example:
          expressir package extract activity.ler --output extracted/
      DESC
      option :output, aliases: "-o", type: :string, required: true,
                      desc: "Output directory for extraction"
      def extract(package_path)
        require "zip"
        require "fileutils"

        unless options[:output]
          raise Expressir::MissingRequiredArgumentError.new(
            "output directory is required",
            usage_hint: "expressir package extract PACKAGE --output OUTPUT_DIR",
          )
        end

        output_dir = options[:output]
        FileUtils.mkdir_p(output_dir)

        Zip::File.open(package_path) do |zip|
          zip.each do |entry|
            dest_path = File.join(output_dir, entry.name)
            FileUtils.mkdir_p(File.dirname(dest_path))
            entry.extract(entry.name, destination_directory: output_dir) unless File.exist?(dest_path)
          end
        end

        say "✓ Package extracted to: #{output_dir}", :green
        say "  Files extracted: #{Dir.glob(File.join(output_dir, '**', '*')).select do |f|
          File.file?(f)
        end.size}", :green
      rescue Expressir::Error
        raise # Re-raise Expressir errors
      rescue StandardError => e
        raise Expressir::PackageExtractError.new(
          "Error extracting package: #{e.message}",
          command_name: "package extract",
        )
      end

      desc "list PACKAGE", "List all elements of a specific type"
      long_desc <<~DESC
        List all elements of a specific type in the package.

        Element types:
        - schema, entity, type, attribute, derived_attribute, inverse_attribute
        - function, procedure, rule, constant, parameter, variable
        - where_rule, unique_rule, enumeration_item, interface

        Type categories (for --type type):
        - select, enumeration, aggregate, defined

        Example:
          expressir package list activity.ler
          expressir package list activity.ler --type entity
          expressir package list activity.ler --type type --category select
          expressir package list activity.ler --type entity --schema action_schema
      DESC
      option :type, type: :string, default: "entity",
                    desc: "Element type to list"
      option :category, type: :string,
                        desc: "Type category (for --type type)"
      option :schema, type: :string,
                      desc: "Filter by schema name"
      option :format, type: :string, default: "text",
                      enum: ["text", "json", "yaml"],
                      desc: "Output format"
      option :show_path, type: :boolean, default: false,
                         desc: "Show full EXPRESS paths"
      option :show_details, type: :boolean, default: false,
                            desc: "Show element details"
      option :count_only, type: :boolean, default: false,
                          desc: "Show count only"
      def list(package_path)
        repo = load_package(package_path)
        search_engine = Expressir::Model::SearchEngine.new(repo)

        results = search_engine.list(
          type: options[:type],
          schema: options[:schema],
          category: options[:category],
        )

        if options[:count_only]
          say results.size.to_s
          return
        end

        case options[:format]
        when "json"
          say results.to_json
        when "yaml"
          say results.to_yaml
        else
          output_text_list(results, options[:type], options[:schema],
                           options[:category])
        end
      rescue Expressir::Error
        raise # Re-raise Expressir errors
      rescue StandardError => e
        raise Expressir::PackageListError.new(
          "Error listing elements: #{e.message}",
          command_name: "package list",
        )
      end

      desc "search PACKAGE PATTERN", "Search for elements matching a pattern"
      long_desc <<~DESC
        Search for elements matching a pattern.

        Pattern formats:
        - name                  Simple name (searches all schemas)
        - schema.element        Qualified name
        - schema.entity.attr    Deep path
        - *.element             Wildcard schema
        - schema.*              Wildcard element
        - *.*.name              Multi-level wildcards
        - action*               Prefix matching

        Example:
          expressir package search activity.ler "action"
          expressir package search activity.ler "action" --type entity
          expressir package search activity.ler "*.*.id" --type attribute
          expressir package search activity.ler "action*" --type entity
          expressir package search activity.ler "action_schema.action.*" --type attribute
      DESC
      option :type, type: :string,
                    desc: "Filter by element type"
      option :category, type: :string,
                        desc: "Type category (for --type type)"
      option :schema, type: :string,
                      desc: "Limit to specific schema"
      option :case_sensitive, type: :boolean, default: false,
                              desc: "Enable case-sensitive matching"
      option :regex, type: :boolean, default: false,
                     desc: "Treat pattern as regex"
      option :exact, type: :boolean, default: false,
                     desc: "Exact match only"
      option :format, type: :string, default: "text",
                      enum: ["text", "json", "yaml"],
                      desc: "Output format"
      option :show_path, type: :boolean, default: false,
                         desc: "Show full EXPRESS paths"
      option :show_details, type: :boolean, default: false,
                            desc: "Show element details"
      option :show_location, type: :boolean, default: false,
                             desc: "Show source location"
      option :limit, type: :numeric,
                     desc: "Limit results"
      option :count_only, type: :boolean, default: false,
                          desc: "Show count only"
      def search(package_path, pattern)
        repo = load_package(package_path)
        search_engine = Expressir::Model::SearchEngine.new(repo)

        results = search_engine.search(
          pattern: pattern,
          type: options[:type],
          schema: options[:schema],
          category: options[:category],
          case_sensitive: options[:case_sensitive],
          regex: options[:regex],
          exact: options[:exact],
        )

        # Apply limit if specified
        results = results.take(options[:limit]) if options[:limit]

        if options[:count_only]
          say results.size.to_s
          return
        end

        case options[:format]
        when "json"
          say results.to_json
        when "yaml"
          say results.to_yaml
        else
          output_text_search_results(results, pattern)
        end
      rescue Expressir::Error
        raise # Re-raise Expressir errors
      rescue StandardError => e
        raise Expressir::PackageSearchError.new(
          "Error searching: #{e.message}",
          command_name: "package search",
        )
      end
      desc "tree PACKAGE", "Display hierarchical tree view of package contents"
      long_desc <<~DESC
        Display a hierarchical tree view of all package contents showing schemas,
        entities, types, functions, and their nested elements.

        Tree structure uses:
        - ├─ for intermediate items
        - └─ for last items
        - │  for continuation lines

        Colors (can be disabled with --no-color):
        - Schemas: bold blue
        - Entities: green
        - Types: yellow
        - Attributes: cyan
        - Functions: magenta
        - Procedures: magenta
        - Rules: red

        Example:
          expressir package tree activity.ler
          expressir package tree activity.ler --depth 2
          expressir package tree activity.ler --schema action_schema
          expressir package tree activity.ler --type entity
          expressir package tree activity.ler --counts
          expressir package tree activity.ler --no-color
      DESC
      option :depth, type: :numeric,
                     desc: "Limit tree depth (1=schemas, 2=entities/types, 3=attributes)"
      option :type, type: :string,
                    desc: "Filter to show only specific element type (entity, type, function, etc.)"
      option :schema, type: :string,
                      desc: "Show tree for specific schema only"
      option :no_color, type: :boolean, default: false,
                        desc: "Disable colors"
      option :counts, type: :boolean, default: false,
                      desc: "Show element counts at each level"
      def tree(package_path)
        require "paint"

        repo = load_package(package_path)

        # Filter schemas if requested
        schemas = if options[:schema]
                    (repo.schemas || []).select { |s| s.id == options[:schema] }
                  else
                    repo.schemas || []
                  end

        if schemas.empty?
          say "No schemas found", :yellow
          return
        end

        # Display package name
        package_name = File.basename(package_path)
        say colorize(package_name, :bold)

        # Display tree
        schemas.each_with_index do |schema, idx|
          is_last_schema = idx == schemas.size - 1
          display_schema_tree(schema, is_last_schema, "", 1)
        end
      rescue Expressir::Error
        raise # Re-raise Expressir errors
      rescue StandardError => e
        raise Expressir::PackageTreeError.new(
          "Error displaying tree: #{e.message}",
          command_name: "package tree",
        )
      end

      private

      # Build package options from CLI options
      # @return [Hash] Package options
      def build_package_options
        {
          name: options[:name] || "Unnamed Package",
          version: options[:version],
          description: options[:description] || "",
          express_mode: options[:express_mode],
          resolution_mode: options[:resolution_mode],
          serialization_format: options[:serialization_format],
        }
      end

      # Load package and return repository
      # @param package_path [String] Path to .ler file
      # @return [Model::Repository] Loaded repository
      def load_package(package_path)
        unless File.exist?(package_path)
          raise Expressir::PackageNotFoundError.new(package_path)
        end

        Expressir::Model::Repository.from_package(package_path)
      end

      # Load package metadata without full repository
      # @param package_path [String] Path to .ler file
      # @return [Package::Metadata] Package metadata
      def load_package_metadata(package_path)
        require "zip"

        Zip::File.open(package_path) do |zip|
          entry = zip.find_entry("metadata.yaml")
          raise "Metadata not found in package" unless entry

          Expressir::Package::Metadata.from_yaml(entry.get_input_stream.read)
        end
      end

      # Output package info in text format
      # @param metadata [Package::Metadata] Package metadata
      # @param repo [Model::Repository] Repository instance
      # @return [void]
      def output_text_info(metadata, repo)
        stats = repo.statistics

        say "Package Information", :bold
        say "=" * 50
        say "Name:        #{metadata.name}" if metadata.name && !metadata.name.empty?
        say "Version:     #{metadata.version}" if metadata.version && !metadata.version.empty?
        say "Description: #{metadata.description}" if metadata.description && !metadata.description.to_s.empty?
        say "Created:     #{metadata.created_at}" if metadata.created_at && !metadata.created_at.to_s.empty?
        say "Created by:  #{metadata.created_by}" if metadata.created_by && !metadata.created_by.to_s.empty? && metadata.created_by != "expressir"
        say ""
        say "Configuration", :bold
        say "-" * 50
        say "Express mode:         #{metadata.express_mode}" if metadata.express_mode && !metadata.express_mode.to_s.empty?
        say "Resolution mode:      #{metadata.resolution_mode}" if metadata.resolution_mode && !metadata.resolution_mode.to_s.empty?
        say "Serialization format: #{metadata.serialization_format}" if metadata.serialization_format && !metadata.serialization_format.to_s.empty?
        say ""
        say "Statistics", :bold
        say "-" * 50
        say "Total schemas:    #{stats[:total_schemas]}"
        say "Total entities:   #{stats[:total_entities]}"
        say "Total types:      #{stats[:total_types]}"
        say "Total functions:  #{stats[:total_functions]}"
        say "Total rules:      #{stats[:total_rules]}"
        say "Total procedures: #{stats[:total_procedures]}"
      end

      # Output package info in JSON format
      # @param metadata [Package::Metadata] Package metadata
      # @param repo [Model::Repository] Repository instance
      # @return [void]
      def output_json_info(metadata, repo)
        stats = repo.statistics
        # Convert symbol keys to strings recursively, handle nil stats
        stats_hash = stats.is_a?(Hash) ? stringify_keys(stats) : {}

        info = {
          "metadata" => stringify_keys(metadata.to_h),
          "statistics" => stats_hash,
        }
        say info.to_json
      end

      # Output package info in YAML format
      # @param metadata [Package::Metadata] Package metadata
      # @param repo [Model::Repository] Repository instance
      # @return [void]
      def output_yaml_info(metadata, repo)
        stats = repo.statistics
        # Convert symbol keys to strings recursively, handle nil stats
        stats_hash = stats.is_a?(Hash) ? stringify_keys(stats) : {}

        info = {
          "metadata" => stringify_keys(metadata.to_h),
          "statistics" => stats_hash,
        }
        say info.to_yaml
      end

      # Recursively stringify hash keys
      # @param obj [Object] Object to stringify
      # @return [Object] Object with stringified keys
      def stringify_keys(obj)
        case obj
        when Hash
          obj.transform_keys(&:to_s).transform_values { |v| stringify_keys(v) }
        when Array
          obj.map { |v| stringify_keys(v) }
        else
          obj
        end
      end

      # Display schema in tree format
      # @param schema [Declarations::Schema] Schema to display
      # @param is_last [Boolean] Whether this is the last item
      # @param prefix [String] Current indentation prefix
      # @param current_depth [Integer] Current tree depth
      # @return [void]
      def display_schema_tree(schema, is_last, prefix, current_depth)
        return if options[:depth] && current_depth > options[:depth]
        return if options[:type] && options[:type] != "schema"

        # Build schema line
        connector = is_last ? "└─ " : "├─ "
        counts_text = build_counts_text(schema) if options[:counts]
        schema_text = "#{schema.id} (schema)#{counts_text}"

        say "#{prefix}#{connector}#{colorize(schema_text, :blue, :bold)}"

        # Don't show children if depth limit reached
        return if options[:depth] && current_depth >= options[:depth]

        # Build new prefix for children
        child_prefix = prefix + (is_last ? "   " : "│  ")

        # Collect all displayable children
        children = collect_schema_children(schema)

        # Display children
        children.each_with_index do |child, idx|
          is_last_child = idx == children.size - 1
          display_element_tree(child[:element], child[:type], is_last_child,
                               child_prefix, current_depth + 1)
        end
      end

      # Collect schema children based on filters
      # @param schema [Declarations::Schema] Schema to collect from
      # @return [Array<Hash>] Array of child elements with type
      def collect_schema_children(schema)
        children = []

        # Add entities
        if should_include_type?("entity") && schema.entities
          schema.entities.each do |e|
            children << { element: e, type: "entity" }
          end
        end

        # Add types
        if should_include_type?("type") && schema.types
          schema.types.each { |t| children << { element: t, type: "type" } }
        end

        # Add functions
        if should_include_type?("function") && schema.functions
          schema.functions.each do |f|
            children << { element: f, type: "function" }
          end
        end

        # Add procedures
        if should_include_type?("procedure") && schema.procedures
          schema.procedures.each do |p|
            children << { element: p, type: "procedure" }
          end
        end

        # Add rules
        if should_include_type?("rule") && schema.rules
          schema.rules.each { |r| children << { element: r, type: "rule" } }
        end

        children
      end

      # Display element in tree format
      # @param element [ModelElement] Element to display
      # @param type [String] Element type
      # @param is_last [Boolean] Whether this is the last item
      # @param prefix [String] Current indentation prefix
      # @param current_depth [Integer] Current tree depth
      # @return [void]
      def display_element_tree(element, type, is_last, prefix, current_depth)
        return if options[:depth] && current_depth > options[:depth]

        connector = is_last ? "└─ " : "├─ "
        element_text = format_element_text(element, type)
        color = element_color(type)

        say "#{prefix}#{connector}#{colorize(element_text, color)}"

        # Don't show children if depth limit reached
        return if options[:depth] && current_depth >= options[:depth]

        # Build new prefix for children
        child_prefix = prefix + (is_last ? "   " : "│  ")

        # Display children based on element type
        case type
        when "entity"
          display_entity_children(element, child_prefix, current_depth + 1)
        when "type"
          display_type_children(element, child_prefix, current_depth + 1)
        when "function", "procedure"
          display_callable_children(element, child_prefix, current_depth + 1)
        end
      end

      # Display entity children (attributes)
      # @param entity [Declarations::Entity] Entity to display
      # @param prefix [String] Current indentation prefix
      # @param current_depth [Integer] Current tree depth
      # @return [void]
      def display_entity_children(entity, prefix, current_depth)
        return if options[:depth] && current_depth > options[:depth]

        children = []

        # Add explicit attributes
        if should_include_type?("attribute") && entity.attributes
          entity.attributes.each do |a|
            children << { element: a, type: "attribute" }
          end
        end

        # Add derived attributes
        if should_include_type?("derived_attribute") && entity.derived_attributes
          entity.derived_attributes.each do |a|
            children << { element: a, type: "derived_attribute" }
          end
        end

        # Add inverse attributes
        if should_include_type?("inverse_attribute") && entity.inverse_attributes
          entity.inverse_attributes.each do |a|
            children << { element: a, type: "inverse_attribute" }
          end
        end

        # Show summary if too many and not showing all
        if children.size > 5 && !should_show_all_attributes?
          # Show first few
          children.take(3).each_with_index do |child, _idx|
            display_element_tree(child[:element], child[:type], false, prefix,
                                 current_depth)
          end

          # Show summary
          remaining = children.size - 3
          summary = "... (#{remaining} more #{pluralize('attribute',
                                                        remaining)})"
          say "#{prefix}└─ #{colorize(summary, :gray)}"
        else
          # Show all
          children.each_with_index do |child, idx|
            is_last = idx == children.size - 1
            display_element_tree(child[:element], child[:type], is_last,
                                 prefix, current_depth)
          end
        end
      end

      # Display type children
      # @param type_elem [Declarations::Type] Type to display
      # @param prefix [String] Current indentation prefix
      # @param current_depth [Integer] Current tree depth
      # @return [void]
      def display_type_children(type_elem, prefix, current_depth)
        return if options[:depth] && current_depth > options[:depth]

        # For SELECT types, show items
        if type_elem.underlying_type.is_a?(Expressir::Model::DataTypes::Select) && type_elem.underlying_type.items
          items = type_elem.underlying_type.items
          if items.size > 5 && !should_show_all_attributes?
            # Show first few items
            items.take(3).each_with_index do |item, _idx|
              connector = "├─ "
              say "#{prefix}#{connector}#{colorize(item.ref || item.id, :cyan)}"
            end

            # Items summary
            remaining = items.size - 3
            items_summary = "... [#{remaining} more items]"
            say "#{prefix}└─ #{colorize(items_summary, :gray)}"

          else
            items.each_with_index do |item, idx|
              is_last = idx == items.size - 1
              connector = is_last ? "└─ " : "├─ "
              say "#{prefix}#{connector}#{colorize(item.ref || item.id, :cyan)}"
            end
          end
        end
      end

      # Display function/procedure children (parameters)
      # @param callable [Declarations::Function, Declarations::Procedure] Callable to display
      # @param prefix [String] Current indentation prefix
      # @param current_depth [Integer] Current tree depth
      # @return [void]
      def display_callable_children(callable, prefix, current_depth)
        return if options[:depth] && current_depth > options[:depth]
        return unless should_include_type?("parameter")
        return unless callable.parameters

        callable.parameters.each_with_index do |param, idx|
          is_last = idx == callable.parameters.size - 1
          display_element_tree(param, "parameter", is_last, prefix,
                               current_depth)
        end
      end

      # Format element text with type information
      # @param element [ModelElement] Element to format
      # @param type [String] Element type
      # @return [String] Formatted text
      def format_element_text(element, type)
        case type
        when "entity", "type", "function", "procedure", "rule"
          "#{element.id} (#{type})"
        when "attribute", "derived_attribute", "inverse_attribute", "parameter"
          type_info = extract_type_info(element)
          "#{element.id} (#{type.sub('_attribute', '')}): #{type_info}"
        when "parameter"
          type_info = extract_type_info(element)
          "#{element.id} (parameter): #{type_info}"
        else
          "#{element.id} (#{type})"
        end
      end

      # Extract type information from attribute/parameter
      # @param element [Attribute, Parameter] Element with type
      # @return [String] Type description
      def extract_type_info(element)
        return "ANY" unless element.type

        type = element.type
        case type
        when Expressir::Model::DataTypes::Set
          "SET"
        when Expressir::Model::DataTypes::List
          "LIST"
        when Expressir::Model::DataTypes::Array
          "ARRAY"
        when Expressir::Model::References::SimpleReference
          type.ref || type.id
        when Expressir::Model::DataTypes::String
          "STRING"
        when Expressir::Model::DataTypes::Integer
          "INTEGER"
        when Expressir::Model::DataTypes::Real
          "REAL"
        when Expressir::Model::DataTypes::Boolean
          "BOOLEAN"
        when Expressir::Model::DataTypes::Logical
          "LOGICAL"
        when Expressir::Model::DataTypes::Number
          "NUMBER"
        else
          type.class.name.split("::").last
        end
      end

      # Build counts text for schema
      # @param schema [Declarations::Schema] Schema
      # @return [String] Counts text
      def build_counts_text(schema)
        counts = []
        entities_count = schema.entities&.size || 0
        types_count = schema.types&.size || 0
        functions_count = schema.functions&.size || 0

        if entities_count.positive?
          counts << "#{entities_count} #{pluralize('entity',
                                                   entities_count)}"
        end
        if types_count.positive?
          counts << "#{types_count} #{pluralize('type',
                                                types_count)}"
        end
        if functions_count.positive?
          counts << "#{functions_count} #{pluralize('function',
                                                    functions_count)}"
        end

        counts.any? ? " [#{counts.join(', ')}]" : ""
      end

      # Colorize text based on options
      # @param text [String] Text to colorize
      # @param color [Symbol] Color name
      # @param style [Symbol, nil] Optional style (bold, etc.)
      # @return [String] Colorized or plain text
      def colorize(text, color, style = nil)
        return "" if text.nil?
        return text if options[:no_color]

        if style
          Paint[text, color, style]
        else
          Paint[text, color]
        end
      end

      # Get color for element type
      # @param type [String] Element type
      # @return [Symbol] Color name
      def element_color(type)
        case type
        when "entity"
          :green
        when "type"
          :yellow
        when "attribute", "derived_attribute", "inverse_attribute", "parameter"
          :cyan
        when "function", "procedure"
          :magenta
        when "rule"
          :red
        else
          :white
        end
      end

      # Check if type should be included based on filter
      # @param type [String] Element type to check
      # @return [Boolean] Whether to include
      def should_include_type?(type)
        return true unless options[:type]

        # Handle attribute variations
        return true if options[:type] == "attribute" && type.end_with?("_attribute")

        options[:type] == type
      end

      # Check if all attributes should be shown
      # @return [Boolean] Whether to show all attributes
      def should_show_all_attributes?
        # Show all if specifically filtering for attributes
        options[:type]&.include?("attribute")
      end

      # Pluralize word based on count
      # @param word [String] Word to pluralize
      # @param count [Integer] Count
      # @return [String] Singular or plural form
      def pluralize(word, count)
        count == 1 ? word : "#{word}s"
      end

      # Output validation results in text format
      # @param validation [Hash] Validation results
      # @return [void]
      def output_text_validation(validation)
        if validation[:valid?]
          say "✓ Package is valid", :green
        else
          say "✗ Validation failed", :red
          say ""
          errors = validation[:errors] || []
          say "Errors (#{errors.size}):", :bold
          errors.each_with_index do |e, i|
            error_msg = if e.is_a?(Hash)
                          # Format hash errors properly
                          msg = e[:message] || "Unknown error"
                          type = e[:type] ? "[#{e[:type]}] " : ""
                          "#{type}#{msg}"
                        else
                          # Fallback for string errors
                          e.to_s
                        end
            say "  #{i + 1}. #{error_msg}", :red
            if e.is_a?(Hash) && e[:schema]
              say "     Schema: #{e[:schema]}",
                  :red
            end
            if e[:referenced_schema]
              say "     Referenced: #{e[:referenced_schema]}",
                  :red
            end
            if e[:interface_type]
              say "     Interface: #{e[:interface_type]}", :red
            end
            say "     Item: #{e[:item]}", :red if e[:item]
            say "     Fix: #{e[:fix_suggestion]}", :yellow if e[:fix_suggestion]
            say "" unless i == errors.size - 1
          end
        end

        warnings = validation[:warnings]
        if warnings&.any?
          say ""
          say "Warnings (#{warnings.size}):", :bold
          warnings.each_with_index do |w, i|
            say "  #{i + 1}. #{w[:message]}", :yellow
            say "     Schema: #{w[:schema]}", :yellow if w[:schema]
            if w[:fix_suggestion]
              say "     Fix: #{w[:fix_suggestion]}", :yellow
            end
            say "" unless i == warnings.size - 1
          end
        end

        # Show detailed interface report if available
        if validation[:interface_report]
          say ""
          say validation[:interface_report]
        end
      end

      # Output validation results in JSON format
      # @param validation [Hash] Validation results
      # @return [void]
      def output_json_validation(validation)
        say validation.to_json
      end

      # Output validation results in YAML format
      # @param validation [Hash] Validation results
      # @return [void]
      def output_yaml_validation(validation)
        say validation.to_yaml
      end

      # Output list results in text format
      # @param results [Array<Hash>] List results
      # @param type [String] Element type
      # @param schema_filter [String, nil] Schema filter
      # @param category_filter [String, nil] Category filter
      # @return [void]
      def output_text_list(results, type, schema_filter, category_filter)
        filters = []
        filters << "type: #{type}"
        filters << "schema: #{schema_filter}" if schema_filter
        filters << "category: #{category_filter}" if category_filter
        filter_text = filters.join(", ")

        say "Elements (#{filter_text})", :bold
        say "Total: #{results.size}"
        say "=" * 60

        results.each do |elem|
          if options[:show_path] && elem[:path]
            say elem[:path]
          elsif elem[:schema]
            category_label = elem[:category] ? " [#{elem[:category]}]" : ""
            say "#{elem[:schema]}.#{elem[:id]}#{category_label}"
          else
            say elem[:id] || "(unnamed)"
          end
        end
      end

      # Output search results in text format
      # @param results [Array<Hash>] Search results
      # @param pattern [String] Search pattern
      # @return [void]
      def output_text_search_results(results, pattern)
        say "Search Results for: #{pattern}", :bold
        say "Total: #{results.size}"
        say "=" * 60

        results.each do |elem|
          type_label = "[#{elem[:type]}]"

          if options[:show_path] && elem[:path]
            say "#{type_label.ljust(20)} #{elem[:path]}"
          elsif elem[:schema]
            category_label = elem[:category] ? " [#{elem[:category]}]" : ""
            say "#{type_label.ljust(20)} #{elem[:schema]}.#{elem[:id]}#{category_label}"
          else
            say "#{type_label.ljust(20)} #{elem[:id] || '(unnamed)'}"
          end
        end
      end
    end
  end
end
