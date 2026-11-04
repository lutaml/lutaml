# frozen_string_literal: true

require_relative "base_package_config"

module Lutaml
  module Xsd
    # Represents a loaded package as a source of schemas/types
    # Not serializable - created at runtime from BasePackageConfig
    class PackageSource
      attr_reader :package_path, :config, :repository

      # @param package_path [String] Path to the LXR package
      # @param config [BasePackageConfig] Configuration for this package
      # @param repository [SchemaRepository] Loaded schema repository
      def initialize(package_path:, config:, repository:)
        @package_path = package_path
        @config = config
        @repository = repository
      end

      # Get priority for conflict resolution
      # @return [Integer]
      def priority
        @config.priority
      end

      # Get conflict resolution strategy
      # @return [String]
      def conflict_resolution
        @config.conflict_resolution
      end

      # Get all namespaces in this package
      # @return [Array<String>]
      def namespaces
        @repository.all_namespaces
      end

      # Get all type names in a specific namespace
      # @param namespace_uri [String] The namespace URI
      # @return [Array<String>]
      def types_in_namespace(namespace_uri)
        @repository.all_type_names(namespace: namespace_uri)
      end

      # Get all schema files in this package
      # @return [Array<String>]
      def schema_files
        @repository.files || []
      end

      # Get namespace remapping rules
      # @return [Array<NamespaceUriRemapping>]
      def namespace_remapping
        @config.namespace_remapping || []
      end

      # Check if a schema should be included
      # @param schema_path [String] Schema file path
      # @return [Boolean]
      def include_schema?(schema_path)
        @config.include_schema?(schema_path)
      end

      # String representation
      # @return [String]
      def to_s
        "PackageSource(#{File.basename(@package_path)}, priority=#{priority})"
      end

      # Detailed inspection
      # @return [String]
      def inspect
        "#<PackageSource:#{object_id} " \
          "path=#{@package_path.inspect} " \
          "priority=#{priority} " \
          "strategy=#{conflict_resolution} " \
          "namespaces=#{namespaces.size}>"
      end
    end
  end
end
