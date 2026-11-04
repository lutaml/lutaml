# frozen_string_literal: true

module Expressir
  module Manifest
    # Validates schema manifests for completeness and integrity
    # Performs three types of validation:
    # 1. File existence - checks if schema files exist
    # 2. Path completeness - warns about missing paths
    # 3. Referential integrity - validates USE/REFERENCE FROM resolution
    class Validator
      attr_reader :manifest, :options

      # Initialize validator
      # @param manifest [SchemaManifest] The manifest to validate
      # @param options [Hash] Validation options
      # @option options [Boolean] :verbose Enable verbose output
      def initialize(manifest, options = {})
        @manifest = manifest
        @options = options
        @base_dirs = extract_base_dirs_from_manifest
      end

      # Validate that all schema files exist on disk
      # @return [Array<Hash>] Array of error hashes with :schema, :path, :message
      def validate_file_existence
        errors = []
        manifest.schemas.each do |schema_entry|
          next if schema_entry.path.nil? || schema_entry.path.empty?

          unless File.exist?(schema_entry.path)
            errors << {
              schema: schema_entry.id,
              path: schema_entry.path,
              message: "Schema file not found: #{schema_entry.path} (#{schema_entry.id})",
            }
          end
        end
        errors
      end

      # Validate that all schemas have paths specified
      # @return [Array<Hash>] Array of warning hashes with :schema, :message
      def validate_path_completeness
        warnings = []
        manifest.schemas.each do |schema_entry|
          if schema_entry.path.nil? || schema_entry.path.empty?
            warnings << {
              schema: schema_entry.id,
              message: "Schema '#{schema_entry.id}' has no path specified - please provide path",
            }
          end
        end
        warnings
      end

      # Validate that manifest IDs match actual schema names in files
      # @return [Array<Hash>] Array of error hashes with :schema, :path, :actual_name, :message
      def validate_schema_names
        errors = []
        manifest.schemas.each do |schema_entry|
          next if schema_entry.path.nil? || schema_entry.path.empty?
          next unless File.exist?(schema_entry.path)

          begin
            actual_name = extract_schema_name(schema_entry.path)
            if actual_name != schema_entry.id
              errors << {
                schema: schema_entry.id,
                path: schema_entry.path,
                actual_name: actual_name,
                message: "Schema ID mismatch: manifest has '#{schema_entry.id}' but file declares '#{actual_name}'",
              }
            end
          rescue StandardError
            # Skip validation if we can't parse the file
            next
          end
        end
        errors
      end

      # Validate referential integrity using DependencyResolver
      # Checks that all USE FROM and REFERENCE FROM interfaces can be resolved
      # @return [Array<Hash>] Array of error hashes with interface details
      def validate_referential_integrity
        errors = []

        # Filter schemas to validate
        schemas_to_validate = manifest.schemas.select do |s|
          !s.path.nil? && !s.path.empty? && File.exist?(s.path)
        end

        # Show header if verbose
        if @options[:verbose]
          puts "Validating referential integrity for #{schemas_to_validate.size} schemas..."
          puts ""
        end

        # Create resolver ONCE for all schemas (efficiency)
        # Share verbose output behavior with manifest create command (DRY)
        resolver = Model::DependencyResolver.new(
          base_dirs: @base_dirs,
          schema_registry: build_schema_registry,
          verbose: @options[:verbose], # Let resolver show detailed interface resolution
        )

        schemas_to_validate.each do |schema_entry|
          # Extract interfaces from this schema
          begin
            interfaces = resolver.extract_interfaces(schema_entry.path)
          rescue StandardError => e
            errors << {
              schema: schema_entry.id,
              path: schema_entry.path,
              message: "Failed to parse schema: #{e.message}",
            }
            next
          end

          # Check each interface can be resolved
          # The resolver will print verbose output for each resolution when verbose=true
          interfaces.each do |interface|
            # Print schema name context if verbose (matches create command style)
            if @options[:verbose]
              print "  #{interface[:kind]} FROM #{interface[:schema_name]} (in #{schema_entry.id}): "
            end

            resolved_path = resolver.resolve_schema_location(
              interface[:schema_name],
              interface[:kind],
              schema_entry.path,
            )

            if resolved_path.nil?
              puts "\e[31m✗ not found\e[0m" if @options[:verbose]

              errors << {
                schema: schema_entry.id,
                path: schema_entry.path,
                interface_kind: interface[:kind],
                referenced_schema: interface[:schema_name],
                message: "Cannot resolve #{interface[:kind]} FROM #{interface[:schema_name]} in #{schema_entry.id}",
              }
            elsif @options[:verbose]
              relative_path = File.basename(resolved_path)
              puts "\e[32m✓\e[0m #{relative_path}"
            end
          end
        end

        errors
      end

      private

      # Extract the actual schema name from a schema file by parsing it
      # @param schema_path [String] Path to the schema file
      # @return [String] The schema name declared in the file
      def extract_schema_name(schema_path)
        repo = Expressir::Express::Parser.from_file(schema_path)
        schema = repo.schemas.first
        schema&.id || File.basename(schema_path, ".*")
      end

      # Build schema registry from manifest entries
      # Maps schema IDs to their file paths
      # @return [Hash<String, String>] Schema name => path mapping
      def build_schema_registry
        registry = {}
        manifest.schemas.each do |schema_entry|
          next if schema_entry.id.nil?
          next if schema_entry.path.nil? || schema_entry.path.empty?

          registry[schema_entry.id] = schema_entry.path
        end
        registry
      end

      # Extract base directories from manifest schema paths
      # @return [Array<String>] List of unique base directories
      def extract_base_dirs_from_manifest
        dirs = manifest.schemas
          .reject { |s| s.path.nil? || s.path.empty? }
          .map { |s| File.dirname(File.expand_path(s.path)) }
          .uniq

        # If no directories found, use current directory
        dirs.empty? ? [Dir.pwd] : dirs
      end
    end
  end
end
