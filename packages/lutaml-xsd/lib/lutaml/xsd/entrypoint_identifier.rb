# frozen_string_literal: true

module Lutaml
  module Xsd
    # Identifies entrypoint schemas in a package
    # Entrypoints are schemas that are explicitly listed as entry files
    # in the package metadata
    class EntrypointIdentifier
      attr_reader :package

      # @param package [SchemaRepositoryPackage] Package to analyze
      def initialize(package)
        @package = package
      end

      # Identify entrypoint schemas
      # @return [Array<Hash>] Array of entrypoint info hashes
      def identify_entrypoints
        # Get metadata from package first, before loading repository
        validation = package.validate
        metadata = validation.metadata

        entrypoint_files = metadata&.[]("files") || []

        # Now load repository to get schemas
        repository = package.load_repository

        entrypoint_files.filter_map do |file_path|
          schema = find_schema_by_path(repository, file_path)
          next unless schema

          {
            file: File.basename(file_path),
            path: file_path,
            namespace: schema.target_namespace,
            schema: schema,
            role: "Root schema",
          }
        end
      end

      # Get all dependencies for entrypoints
      # @return [Array<Hash>] Array of dependency info hashes
      def get_dependencies
        # Get metadata from package
        validation = package.validate
        metadata = validation.metadata

        package.load_repository
        all_schemas = Lutaml::Xml::Schema::Xsd::Schema.processed_schemas

        # Exclude entrypoint files from dependencies
        entrypoint_files = metadata&.[]("files") || []
        entrypoint_paths = Set.new(entrypoint_files.map do |f|
          File.basename(f)
        end)

        dependencies = []
        all_schemas.each do |location, schema|
          basename = File.basename(location)
          next if entrypoint_paths.include?(basename)

          dependencies << {
            file: basename,
            path: location,
            namespace: schema.target_namespace,
            schema: schema,
          }
        end

        dependencies
      end

      private

      # Find schema by file path
      # @param repository [SchemaRepository] Repository to search
      # @param file_path [String] File path to find
      # @return [Schema, nil] Found schema or nil
      def find_schema_by_path(_repository, file_path)
        all_schemas = Lutaml::Xml::Schema::Xsd::Schema.processed_schemas

        # Try exact match first
        schema = all_schemas[file_path]
        return schema if schema

        # Try basename match
        basename = File.basename(file_path)
        all_schemas.each do |location, schema|
          return schema if File.basename(location) == basename
        end

        nil
      end
    end
  end
end
