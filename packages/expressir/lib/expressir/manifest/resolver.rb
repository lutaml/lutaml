# frozen_string_literal: true

module Expressir
  module Manifest
    # Resolves schema paths in manifests using pattern-based path discovery
    # Attempts to find file paths for schemas with missing or empty paths
    class Resolver
      attr_reader :manifest, :options, :base_dirs

      # Initialize resolver
      # @param manifest [SchemaManifest] The manifest to resolve
      # @param options [Hash] Resolution options
      # @option options [Array<String>] :base_dirs Base directories to search
      # @option options [Boolean] :verbose Enable verbose output
      def initialize(manifest, options = {})
        @manifest = manifest
        @options = options
        @base_dirs = extract_base_dirs_from_manifest

        # Override with explicit base_dirs if provided
        if options[:base_dirs]
          @base_dirs = Array(options[:base_dirs]).map do |d|
            File.expand_path(d)
          end
        end
      end

      # Resolve paths for all schemas in manifest
      # Works like manifest create - resolves all dependencies from schemas with paths
      # @return [SchemaManifest] New manifest with resolved paths and dependencies
      def resolve_paths
        # Create new manifest to avoid modifying original
        resolved_manifest = SchemaManifest.new

        # Track all resolved schema paths
        all_resolved_paths = Set.new
        all_unresolved = []

        # Find schemas with valid paths to use as roots
        root_schemas = manifest.schemas.select do |s|
          !s.path.nil? && !s.path.empty? && File.exist?(s.path)
        end

        if root_schemas.empty?
          # No roots, just try to resolve individual schemas
          say "No valid schema paths found, attempting simple path resolution..." if options[:verbose]
          return resolve_paths_simple
        end

        say "Resolving dependencies from #{root_schemas.size} root schema(s)..." if options[:verbose]
        say_base_dirs

        # For each root schema, resolve all its dependencies
        root_schemas.each do |root_entry|
          resolver = Model::DependencyResolver.new(
            base_dirs: @base_dirs,
            schema_registry: build_schema_registry,
            verbose: options[:verbose],
          )

          # Resolve all dependencies for this root
          resolved_paths = resolver.resolve_dependencies(root_entry.path)
          all_resolved_paths.merge(resolved_paths)
          all_unresolved.concat(resolver.unresolved)
        end

        # Add all resolved schemas to manifest
        all_resolved_paths.each do |path|
          schema_id = extract_schema_name(path)
          resolved_manifest.schemas << SchemaManifestEntry.new(
            id: schema_id,
            path: path,
          )
        end

        # Add unresolved schemas with empty paths
        all_unresolved.uniq { |e| e[:schema_name] }.each do |entry|
          # Only add if not already in manifest
          unless resolved_manifest.schemas.any? do |s|
            s.id == entry[:schema_name]
          end
            resolved_manifest.schemas << SchemaManifestEntry.new(
              id: entry[:schema_name],
              path: "",
            )
          end
        end

        resolved_manifest
      end

      # Simple path resolution - just try to find missing paths
      # Used when no valid root schemas are available
      # @return [SchemaManifest] New manifest with resolved paths
      def resolve_paths_simple
        resolved_manifest = SchemaManifest.new

        resolver = Model::DependencyResolver.new(
          base_dirs: @base_dirs,
          schema_registry: build_schema_registry,
          verbose: options[:verbose],
        )

        manifest.schemas.each do |schema_entry|
          resolved_entry = resolve_schema_entry(schema_entry, resolver)
          resolved_manifest.schemas << resolved_entry
        end

        resolved_manifest
      end

      # Get resolution statistics
      # @return [Hash] Resolution statistics
      def statistics
        unresolved_count = manifest.schemas.count do |s|
          s.path.nil? || s.path.empty?
        end
        {
          total_schemas: manifest.schemas.size,
          resolved: manifest.schemas.size - unresolved_count,
          unresolved: unresolved_count,
          base_dirs: @base_dirs,
        }
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

      # Say message (only used when verbose is enabled)
      def say(message)
        puts message if options[:verbose]
      end

      # Say base directories with numbered labels
      def say_base_dirs
        if options[:verbose] && @base_dirs
          say "  Using base directories:"
          @base_dirs.each_with_index do |dir, index|
            say "    - [source #{index + 1}]: #{dir}"
          end
        end
      end

      # Resolve a single schema entry
      # @param schema_entry [SchemaManifestEntry] The entry to resolve
      # @param resolver [Model::DependencyResolver] The resolver to use
      # @return [SchemaManifestEntry] New entry with resolved path
      def resolve_schema_entry(schema_entry, resolver)
        # If path already exists and is valid, keep it
        if schema_entry.path && !schema_entry.path.empty? && File.exist?(schema_entry.path)
          return SchemaManifestEntry.new(
            id: schema_entry.id,
            path: schema_entry.path,
          )
        end

        # Try to resolve path using DependencyResolver
        resolved_path = resolver.resolve_schema_location(
          schema_entry.id,
          "USE", # Kind doesn't matter for location resolution
          nil, # No current path context
        )

        SchemaManifestEntry.new(
          id: schema_entry.id,
          path: resolved_path || schema_entry.path || "",
        )
      end

      # Build schema registry from manifest entries with valid paths
      # Maps schema IDs to their file paths
      # @return [Hash<String, String>] Schema name => path mapping
      def build_schema_registry
        registry = {}
        manifest.schemas.each do |schema_entry|
          next if schema_entry.id.nil?
          next if schema_entry.path.nil? || schema_entry.path.empty?
          next unless File.exist?(schema_entry.path)

          registry[schema_entry.id] = schema_entry.path
        end
        registry
      end

      # Extract base directories from manifest schema paths
      # @return [Array<String>] List of unique base directories
      def extract_base_dirs_from_manifest
        dirs = manifest.schemas
          .reject { |s| s.path.nil? || s.path.empty? }
          .select { |s| File.exist?(s.path) }
          .map { |s| File.dirname(File.expand_path(s.path)) }
          .uniq

        # If no directories found, use current directory
        dirs.empty? ? [Dir.pwd] : dirs
      end
    end
  end
end
