# frozen_string_literal: true

module Lutaml
  module Xsd
    # Manages namespace prefix information in a repository
    # Single responsibility: analyze and report prefix usage
    class NamespacePrefixManager
      attr_reader :repository

      def initialize(repository)
        @repository = repository
      end

      # Get detailed prefix information
      # Returns array of NamespacePrefixInfo objects
      def detailed_prefix_info
        repository.namespace_mappings.map do |mapping|
          NamespacePrefixInfo.new(mapping, repository)
        end
      end

      # Find schema that defines a namespace
      # @param namespace_uri [String] The namespace URI
      # @return [Schema, nil] The schema defining this namespace
      def find_schema_for_namespace(namespace_uri)
        all_schemas = repository.all_schemas

        all_schemas.each_value do |schema|
          return schema if schema.target_namespace == namespace_uri
        end

        nil
      end

      # Get package location for namespace's schema
      # @param namespace_uri [String] The namespace URI
      # @return [String, nil] The file path or nil if not found
      def get_package_location(namespace_uri)
        all_schemas = repository.all_schemas

        all_schemas.each do |file_path, schema|
          return file_path if schema.target_namespace == namespace_uri
        end

        nil
      end
    end

    # Value object for namespace prefix information
    class NamespacePrefixInfo
      attr_reader :prefix, :uri, :original_schema_location,
                  :package_location, :type_count, :types_by_category

      def initialize(mapping, repository)
        @prefix = mapping.prefix
        @uri = mapping.uri

        # Get schema location information
        manager = NamespacePrefixManager.new(repository)
        @package_location = manager.get_package_location(@uri)
        @original_schema_location = extract_original_location(repository)

        # Get type statistics
        types = repository.types_in_namespace(@uri)
        @type_count = types.size
        @types_by_category = count_types_by_category(types)
      end

      # Convert to hash for JSON/YAML output
      # @return [Hash]
      def to_h
        {
          prefix: prefix,
          uri: uri,
          original_schema_location: original_schema_location,
          package_location: package_location,
          type_count: type_count,
          types_by_category: types_by_category,
        }
      end

      private

      def extract_original_location(repository)
        # Try to find the original schema location from mappings
        mapping = repository.schema_location_mappings&.find do |m|
          m.to.include?(@uri) || @uri.include?(m.from)
        end

        mapping&.from || @package_location
      end

      def count_types_by_category(types)
        counts = Hash.new(0)
        types.each { |type_info| counts[type_info[:type]] += 1 }
        counts
      end
    end
  end
end
