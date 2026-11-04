# frozen_string_literal: true

require "thor"

module Expressir
  module Commands
    # Manifest management CLI commands
    # Handles schema manifest creation and validation
    class Manifest < Thor
      include Thor::Actions

      desc "create ROOT_SCHEMA [MORE_SCHEMAS...]",
           "Generate schema manifest from root schema(s)"
      long_desc <<~DESC
        Generate a YAML manifest of all schemas required for packaging.

        The manifest uses the existing SchemaManifest format:
        schemas:
          schema_id:
            path: /path/to/schema.exp

        Workflow:
        1. Create manifest from root schema
        2. Edit manifest to add paths for schemas with null paths
        3. Validate manifest
        4. Build package using manifest

        Example:
          expressir manifest create schemas/activity/mim.exp \\
            -o activity_manifest.yaml \\
            --base-dirs /path/to/schemas

          # With multiple base directories (space-separated)
          expressir manifest create schemas/activity/mim.exp \\
            -o activity_manifest.yaml \\
            --base-dirs /path/to/resources /path/to/modules

          # Or comma-separated for backward compatibility
          expressir manifest create schemas/activity/mim.exp \\
            -o activity_manifest.yaml \\
            --base-dirs /path/to/resources,/path/to/modules
      DESC
      option :output, aliases: "-o", type: :string, required: true,
                      desc: "Output YAML file path"
      option :base_dirs, type: :array,
                         desc: "Base directories for schema resolution (can be specified multiple times)"
      option :verbose, type: :boolean, default: false,
                       desc: "Show detailed output"
      def create(*root_schemas)
        # Convert string keys to symbols for compatibility with tests
        opts = options.transform_keys(&:to_sym)

        if root_schemas.empty?
          say "Error: At least one root schema is required", :red
          say "Usage: expressir manifest create ROOT_SCHEMA [MORE_SCHEMAS...] -o OUTPUT.yaml",
              :yellow
          raise Thor::Error, "At least one root schema is required"
        end

        # Verify root schemas exist
        root_schemas.each do |schema|
          unless File.exist?(schema)
            say "Error: Root schema not found: #{schema}", :red
            raise Thor::Error, "Root schema not found: #{schema}"
          end
        end

        say "Creating manifest from #{root_schemas.size} root schema(s)..." if opts[:verbose]

        # Parse base directories - now an array directly from Thor
        base_dirs = if opts[:base_dirs]
                      # Thor array type accepts space-separated values in a single flag
                      # or we can also split comma-separated values for backward compatibility
                      opts[:base_dirs].flat_map do |dir|
                        dir.split(",")
                      end.map(&:strip)
                    else
                      # Default to directories containing root schemas
                      root_schemas.map do |s|
                        File.dirname(File.expand_path(s))
                      end.uniq
                    end

        if opts[:verbose]
          say "  Base directories:"
          base_dirs.each_with_index do |dir, index|
            say "    - [source #{index + 1}]: #{dir}"
          end
        end

        # Resolve dependencies
        say "Resolving dependencies..." if opts[:verbose]
        resolver = Expressir::Model::DependencyResolver.new(
          base_dirs: base_dirs,
          verbose: opts[:verbose],
        )

        resolved_paths = resolver.resolve_dependencies(root_schemas.first)

        # Create manifest using existing SchemaManifest class
        manifest = Expressir::SchemaManifest.new

        # Add resolved schemas - use actual schema name from file, not filename
        resolved_paths.each do |path|
          schema_id = extract_schema_name(path)
          manifest.schemas << Expressir::SchemaManifestEntry.new(
            id: schema_id,
            path: path,
          )
        end

        # Add unresolved schemas with empty string paths (not nil to avoid serialization issues)
        resolver.unresolved.uniq { |e| e[:schema_name] }.each do |entry|
          manifest.schemas << Expressir::SchemaManifestEntry.new(
            id: entry[:schema_name],
            path: "",
          )
        end

        # Save manifest
        FileUtils.mkdir_p(File.dirname(opts[:output]))
        File.write(opts[:output], manifest.to_yaml)

        # Use validator for consistent warnings (DRY - single source of truth)
        validator = Expressir::Manifest::Validator.new(manifest, opts)
        path_warnings = validator.validate_path_completeness

        unresolved_count = path_warnings.size
        resolved_count = manifest.schemas.size - unresolved_count

        say "✓ Manifest created: #{opts[:output]}", :green
        say "  Resolved schemas: #{resolved_count}", :green

        # Warn about multiple matches
        stats = resolver.statistics
        if stats[:multiple_matches].any?
          say ""
          say "⚠ Multiple matches found (#{stats[:multiple_matches].size}):",
              :yellow
          stats[:multiple_matches].each do |match_info|
            say "  Schema '#{match_info[:schema_name]}' found in #{match_info[:matches].size} locations:",
                :yellow
            match_info[:matches].each_with_index do |m, idx|
              relative_path = m[:path].sub("#{m[:base_dir]}/", "")
              marker = idx.zero? ? "[USING]" : "       "
              say "    #{marker} [source #{m[:index] + 1}] #{relative_path}",
                  :yellow
            end
          end
          say ""
          say "The first match was used for each schema.", :yellow
          say "If you need a different version, manually edit #{opts[:output]}",
              :yellow
        end

        # Warn about unresolved using validator results
        if path_warnings.any?
          say ""
          say "⚠ Unresolved schemas (#{unresolved_count}):", :yellow
          path_warnings.each { |w| say "  - #{w[:schema]}", :yellow }
          say ""
          say "Please edit #{opts[:output]} and set 'path:' for unresolved schemas",
              :yellow
          say "Then validate with: expressir manifest validate #{opts[:output]}",
              :yellow
        else
          say "  All schemas resolved successfully!", :green
        end
      rescue StandardError => e
        say "Error creating manifest: #{e.message}", :red
        say e.backtrace.join("\n") if options[:verbose]
        raise Thor::Error, "Failed to create manifest: #{e.message}"
      end

      desc "resolve MANIFEST", "Resolve schema paths in manifest"
      long_desc <<~DESC
        Resolve missing or incomplete schema paths in a manifest file.

        This command attempts to find file paths for schemas with missing or empty paths
        by searching in base directories using naming patterns:

        Supported patterns:
        - Resource schemas: {schema_name}.exp
        - Module ARM/MIM: {module_name}/{arm|mim}.exp
          Example: Activity_method_mim -> activity_method/mim.exp

        The resolved manifest is written to the output file, leaving the original unchanged.

        Use this command after 'expressir manifest validate --check-references' fails
        to automatically resolve missing schema paths.

        Examples:
          # Resolve paths using manifest's existing base directories
          expressir manifest resolve manifest.yaml -o resolved_manifest.yaml

          # Resolve with explicit base directories (space-separated)
          expressir manifest resolve manifest.yaml -o resolved.yaml \\
            --base-dirs /path/to/schemas /another/path

          # Or comma-separated for backward compatibility
          expressir manifest resolve manifest.yaml -o resolved.yaml \\
            --base-dirs /path/to/schemas,/another/path

          # With verbose output
          expressir manifest resolve manifest.yaml -o resolved.yaml --verbose
      DESC
      option :output, aliases: "-o", type: :string, required: true,
                      desc: "Output file path for resolved manifest"
      option :base_dirs, type: :array,
                         desc: "Base directories for schema search (can be specified multiple times)"
      option :verbose, type: :boolean, default: false,
                       desc: "Show detailed resolution progress"
      def resolve(manifest_path)
        unless File.exist?(manifest_path)
          say "Error: Manifest file not found: #{manifest_path}", :red
          raise Thor::Error, "Manifest file not found: #{manifest_path}"
        end

        say "Resolving schema paths in: #{manifest_path}..." if options[:verbose]

        # Load manifest
        manifest = Expressir::SchemaManifest.from_file(manifest_path)

        # Parse base directories - now an array directly from Thor
        resolver_options = { verbose: options[:verbose] }
        if options[:base_dirs]
          # Thor array type accepts space-separated values in a single flag
          # or we can also split comma-separated values for backward compatibility
          resolver_options[:base_dirs] = options[:base_dirs].flat_map do |dir|
            dir.split(",")
          end.map(&:strip)
          if options[:verbose]
            say "  Using base directories:"
            resolver_options[:base_dirs].each_with_index do |dir, index|
              say "    - [source #{index + 1}]: #{dir}"
            end
          end
        end

        # Create resolver and resolve paths
        resolver = Expressir::Manifest::Resolver.new(manifest, resolver_options)

        say "Attempting to resolve paths..." if options[:verbose]
        resolved_manifest = resolver.resolve_paths

        # Save resolved manifest
        FileUtils.mkdir_p(File.dirname(options[:output]))
        File.write(options[:output], resolved_manifest.to_yaml)

        # Display statistics based on RESOLVED manifest (like manifest create)
        validator = Expressir::Manifest::Validator.new(resolved_manifest,
                                                       options)
        path_warnings = validator.validate_path_completeness

        unresolved_count = path_warnings.size
        resolved_count = resolved_manifest.schemas.size - unresolved_count

        say "✓ Manifest resolved: #{options[:output]}", :green
        say "  Total schemas: #{resolved_manifest.schemas.size}", :green
        say "  Resolved schemas: #{resolved_count}", :green

        # Warn about unresolved (like manifest create)
        if path_warnings.any?
          say ""
          say "⚠ Unresolved schemas (#{unresolved_count}):", :yellow
          path_warnings.each { |w| say "  - #{w[:schema]}", :yellow }
          say ""
          say "These schemas could not be found in the search directories.",
              :yellow
          say "You may need to:", :yellow
          say "  1. Add more base directories with --base-dirs", :yellow
          say "  2. Manually edit #{options[:output]} and set their paths",
              :yellow
        else
          say "  All schema paths resolved successfully!", :green
        end
      rescue StandardError => e
        say "Error resolving manifest: #{e.message}", :red
        say e.backtrace.join("\n") if options[:verbose]
        raise Thor::Error, "Failed to resolve manifest: #{e.message}"
      end

      desc "validate MANIFEST", "Validate a schema manifest"
      long_desc <<~DESC
        Validate a schema manifest file.

        Validation types:
        - File existence: All schema paths exist on disk
        - Path completeness: All schemas have paths specified (warnings)
        - Referential integrity (--check-references): All USE/REFERENCE FROM resolve

        Examples:
          # Basic validation (file existence and path completeness)
          expressir manifest validate activity_manifest.yaml

          # With referential integrity checking
          expressir manifest validate activity_manifest.yaml --check-references

          # With verbose output
          expressir manifest validate activity_manifest.yaml --check-references --verbose
      DESC
      option :verbose, type: :boolean, default: false,
                       desc: "Show detailed validation results"
      option :check_references, type: :boolean, default: false,
                                desc: "Validate referential integrity using dependency resolver"
      def validate(manifest_path)
        unless File.exist?(manifest_path)
          say "Error: Manifest file not found: #{manifest_path}", :red
          raise Thor::Error, "Manifest file not found: #{manifest_path}"
        end

        # Convert string keys to symbols for compatibility with tests
        opts = options.transform_keys(&:to_sym)

        say "Validating manifest: #{manifest_path}..." if opts[:verbose]

        # Load manifest
        manifest = Expressir::SchemaManifest.from_file(manifest_path)

        # Create validator - SINGLE SOURCE OF TRUTH
        validator = Expressir::Manifest::Validator.new(manifest, opts)

        # Run validations using validator (NO INLINE LOGIC)
        file_errors = validator.validate_file_existence
        path_warnings = validator.validate_path_completeness
        name_errors = validator.validate_schema_names

        reference_errors = []
        if opts[:check_references]
          say "Checking referential integrity..." if opts[:verbose]
          reference_errors = validator.validate_referential_integrity
        end

        # Display results
        display_validation_results(manifest, file_errors, path_warnings,
                                   name_errors, reference_errors)
      rescue StandardError => e
        say "Error validating manifest: #{e.message}", :red
        say e.backtrace.join("\n") if options && options[:verbose]
        raise Thor::Error, "Failed to validate manifest: #{e.message}"
      end

      private

      # Extract the actual schema name from a schema file by parsing it
      # @param schema_path [String] Path to the schema file
      # @return [String] The schema name declared in the file
      def extract_schema_name(schema_path)
        repo = Expressir::Express::Parser.from_file(schema_path)
        schema = repo.schemas.first
        schema&.id || File.basename(schema_path, ".*")
      rescue StandardError
        # Fallback to filename if parsing fails
        File.basename(schema_path, ".*")
      end

      def display_validation_results(manifest, file_errors, path_warnings,
name_errors, reference_errors)
        # Convert string keys to symbols for compatibility with tests
        opts = options.transform_keys(&:to_sym)

        # Calculate counts
        unresolved_count = manifest.schemas.count do |s|
          s.path.nil? || s.path.empty?
        end
        resolved_count = manifest.schemas.size - unresolved_count

        # Determine if validation passed
        has_errors = file_errors.any? || name_errors.any? || reference_errors.any?

        if has_errors
          say "✗ Manifest validation failed", :red
          say ""

          if file_errors.any?
            say "File Errors (#{file_errors.size}):", :red
            file_errors.each { |e| say "  - #{e[:message]}", :red }
            say ""
          end

          if name_errors.any?
            say "Schema Name Errors (#{name_errors.size}):", :red
            name_errors.each { |e| say "  - #{e[:message]}", :red }
            say ""
          end

          if reference_errors.any?
            say "Reference Errors (#{reference_errors.size}):", :red
            reference_errors.each { |e| say "  - #{e[:message]}", :red }
            say ""
          end

          if path_warnings.any?
            say "Warnings (#{path_warnings.size}):", :yellow
            path_warnings.each { |w| say "  - #{w[:message]}", :yellow }
          end

          raise Thor::Error, "Manifest validation failed"
        else
          say "✓ Manifest is valid", :green
          if opts[:verbose]
            say "  Total schemas: #{manifest.schemas.size}",
                :green
          end
          say "  Resolved schemas: #{resolved_count}", :green if opts[:verbose]
          if opts[:verbose] && unresolved_count.positive?
            say "  Unresolved schemas: #{unresolved_count}",
                :green
          end

          if path_warnings.any?
            say ""
            say "Warnings (#{path_warnings.size}):", :yellow
            path_warnings.each { |w| say "  - #{w[:message]}", :yellow }
          end
        end
      end
    end
  end
end
