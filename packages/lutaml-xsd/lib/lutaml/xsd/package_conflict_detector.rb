# frozen_string_literal: true

module Lutaml
  module Xsd
    # Service class for detecting conflicts between packages
    class PackageConflictDetector
      attr_reader :package_configs

      def initialize(package_configs)
        @package_configs = package_configs
        @package_sources = []
      end

      # Detect all conflicts
      # @return [ConflictReport]
      def detect_conflicts
        load_packages

        namespace_conflicts = detect_namespace_conflicts
        type_conflicts = detect_type_conflicts
        schema_conflicts = detect_schema_conflicts

        ConflictReport.from_conflicts(
          namespace_conflicts: namespace_conflicts,
          type_conflicts: type_conflicts,
          schema_conflicts: schema_conflicts,
          package_sources: @package_sources,
        )
      end

      private

      def load_packages
        @package_configs.each do |config|
          unless File.exist?(config.package)
            raise ConfigurationError,
                  "Base package not found: #{config.package}"
          end

          repo = SchemaRepository.from_package(config.package)
          if config.namespace_remapping&.any?
            repo = apply_namespace_remapping(repo,
                                             config)
          end

          @package_sources << PackageSource.new(
            package_path: config.package,
            config: config,
            repository: repo,
          )
        end
      end

      def apply_namespace_remapping(repo, config)
        uri_mappings = {}
        config.namespace_remapping.each do |remap|
          uri_mappings[remap.from_uri] = remap.to_uri
        end

        new_ns_mappings = repo.namespace_mappings.map do |mapping|
          new_uri = uri_mappings[mapping.uri] || mapping.uri
          NamespaceMapping.new(prefix: mapping.prefix, uri: new_uri)
        end

        SchemaRepository.new(
          files: repo.files,
          namespace_mappings: new_ns_mappings,
          schema_location_mappings: repo.schema_location_mappings,
        ).tap do |new_repo|
          new_repo.instance_variable_set(:@parsed_schemas,
                                         repo.instance_variable_get(:@parsed_schemas))
        end
      end

      def detect_namespace_conflicts
        namespace_sources = Hash.new { |h, k| h[k] = [] }

        @package_sources.each do |source|
          source.namespaces.each do |ns_uri|
            namespace_sources[ns_uri] << source
          end
        end

        namespace_sources.select do |_, sources|
          sources.size > 1
        end.map do |ns_uri, sources|
          Conflicts::NamespaceConflict.from_sources(namespace_uri: ns_uri,
                                                    sources: sources)
        end
      end

      def detect_type_conflicts
        type_sources = Hash.new { |h, k| h[k] = [] }

        @package_sources.each do |source|
          source.namespaces.each do |ns_uri|
            source.types_in_namespace(ns_uri).each do |type_name|
              key = "#{ns_uri}||#{type_name}"
              type_sources[key] << source
            end
          end
        end

        type_sources.select do |_, sources|
          sources.size > 1
        end.map do |key, sources|
          ns_uri, type_name = key.split("||", 2)
          Conflicts::TypeConflict.from_sources(
            namespace_uri: ns_uri,
            type_name: type_name,
            sources: sources.uniq,
          )
        end
      end

      def detect_schema_conflicts
        schema_sources = Hash.new { |h, k| h[k] = [] }

        @package_sources.each do |source|
          source.schema_files.each do |schema_file|
            basename = File.basename(schema_file)
            schema_sources[basename] << Conflicts::SchemaFileSource.new(
              package_path: source.package_path,
              schema_file: schema_file,
              priority: source.priority,
            )
          end
        end

        schema_sources.select do |_, sources|
          sources.size > 1
        end.map do |basename, file_sources|
          Conflicts::SchemaConflict.new(
            schema_basename: basename,
            source_files: file_sources,
          )
        end
      end
    end
  end
end
