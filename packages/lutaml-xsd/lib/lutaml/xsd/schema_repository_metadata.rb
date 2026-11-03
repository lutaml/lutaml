# frozen_string_literal: true

module Lutaml
  module Xsd
    # Type category count (simple key-value pair)
    class TypeCategoryCount < Lutaml::Model::Serializable
      attribute :category, :string
      attribute :count, :integer

      yaml do
        map "category", to: :category
        map "count", to: :count
      end
    end

    # Statistics about a schema repository
    class SchemaRepositoryStatistics < Lutaml::Model::Serializable
      attribute :total_schemas, :integer
      attribute :total_types, :integer
      attribute :types_by_category, TypeCategoryCount, collection: true
      attribute :total_namespaces, :integer
      attribute :namespace_prefixes, :integer
      attribute :resolved, :boolean
      attribute :validated, :boolean

      yaml do
        map "total_schemas", to: :total_schemas
        map "total_types", to: :total_types
        map "types_by_category", to: :types_by_category
        map "total_namespaces", to: :total_namespaces
        map "namespace_prefixes", to: :namespace_prefixes
        map "resolved", to: :resolved
        map "validated", to: :validated
      end

      # Create from statistics hash
      # @param stats [Hash] Statistics hash
      # @return [SchemaRepositoryStatistics]
      def self.from_statistics(stats)
        # Convert types_by_category hash to array of TypeCategoryCount objects
        types_by_cat_hash = stats[:types_by_category] || {}
        types_by_cat_array = types_by_cat_hash.map do |category, count|
          TypeCategoryCount.new(category: category.to_s, count: count)
        end

        new(
          total_schemas: stats[:total_schemas],
          total_types: stats[:total_types],
          types_by_category: types_by_cat_array,
          total_namespaces: stats[:total_namespaces],
          namespace_prefixes: stats[:namespace_prefixes],
          resolved: stats[:resolved],
          validated: stats[:validated],
        )
      end
    end

    # Metadata for a schema repository package
    class SchemaRepositoryMetadata < Lutaml::Model::Serializable
      attribute :files, :string, collection: true
      attribute :schema_location_mappings, SchemaLocationMapping,
                collection: true
      attribute :namespace_mappings, NamespaceMapping, collection: true
      attribute :statistics, SchemaRepositoryStatistics
      attribute :serialized_schemas, SerializedSchema, collection: true
      attribute :created_at, :string
      attribute :lutaml_xsd_version, :string
      attribute :name, :string
      attribute :version, :string
      attribute :description, :string
      attribute :created_by, :string
      attribute :xsd_mode, :string
      attribute :resolution_mode, :string
      attribute :serialization_format, :string

      yaml do
        map "files", to: :files
        map "schema_location_mappings", to: :schema_location_mappings
        map "namespace_mappings", to: :namespace_mappings
        map "statistics", to: :statistics
        map "serialized_schemas", to: :serialized_schemas
        map "created_at", to: :created_at
        map "lutaml_xsd_version", to: :lutaml_xsd_version
        map "name", to: :name
        map "version", to: :version
        map "description", to: :description
        map "created_by", to: :created_by
        map "xsd_mode", to: :xsd_mode
        map "resolution_mode", to: :resolution_mode
        map "serialization_format", to: :serialization_format
      end

      # Override to_yaml to include any extra custom metadata fields
      def to_yaml(*)
        hash = to_hash
        # Add any instance variables that aren't part of the schema
        instance_variables.each do |ivar|
          var_name = ivar.to_s.delete_prefix("@")
          next if hash.key?(var_name) || hash.key?(var_name.to_sym)

          value = instance_variable_get(ivar)
          hash[var_name] = value unless value.nil?
        end
        hash.to_yaml(*)
      end

      # Override to_hash to include extra fields
      def to_hash
        hash = super
        # Add any instance variables that aren't part of the schema
        instance_variables.each do |ivar|
          var_name = ivar.to_s.delete_prefix("@")
          next if hash.key?(var_name) || hash.key?(var_name.to_sym)

          value = instance_variable_get(ivar)
          hash[var_name] = value unless value.nil?
        end
        hash
      end

      # Create metadata from a repository
      # @param repository [SchemaRepository] Repository instance
      # @param additional [Hash] Additional metadata fields
      # @return [SchemaRepositoryMetadata]
      def self.from_repository(repository, additional = {})
        # Extract known fields
        metadata = new(
          files: repository.files || [],
          schema_location_mappings: repository.schema_location_mappings || [],
          namespace_mappings: repository.namespace_mappings || [],
          statistics: SchemaRepositoryStatistics.from_statistics(repository.statistics),
          created_at: Time.now.iso8601,
          lutaml_xsd_version: Lutaml::Xsd::VERSION,
          name: additional[:name] || additional["name"],
          version: additional[:version] || additional["version"],
          description: additional[:description] || additional["description"],
          created_by: additional[:created_by] || additional["created_by"],
        )

        # Store any custom metadata fields as instance variables
        known_fields = [:name, :version, :description, :created_by,
                        "name", "version", "description", "created_by"]
        additional.each do |key, value|
          next if known_fields.include?(key)

          # Set as instance variable to be picked up by to_yaml/to_hash
          metadata.instance_variable_set("@#{key}", value)
        end

        metadata
      end
    end
  end
end
