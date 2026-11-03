# frozen_string_literal: true

module Lutaml
  module Xsd
    # Handles serialization of parsed Schema objects for package resolution
    # Uses lutaml-model's built-in to_yaml/from_yaml methods
    class SchemaResolver
      # Serialize all schemas from a repository
      # @param repository [SchemaRepository] Repository with parsed schemas
      # @return [Array<SerializedSchema>] Array of serialized schema objects
      def resolve_schemas(repository)
        all_schemas = repository.all_schemas

        all_schemas.map do |file_path, schema|
          serialize_schema(file_path, schema)
        end
      end

      # Serialize a single schema
      # @param file_path [String] Path to schema file
      # @param schema [Schema] Parsed schema object
      # @return [SerializedSchema] Serialized schema object
      def serialize_schema(file_path, schema)
        # Use SerializedSchema which handles Schema complexity
        # (avoiding circular references from imports/includes)
        SerializedSchema.from_schema(file_path, schema)
      end

      # Deserialize schemas and load into repository
      # @param repository [SchemaRepository] Repository to load into
      # @param serialized_schemas [Array<Hash>] Serialized schema data
      def load_serialized_schemas(_repository, serialized_schemas)
        return unless serialized_schemas&.any?

        serialized_schemas.each do |schema_data|
          # Create SerializedSchema from hash data
          file_path = schema_data["file_path"] || schema_data[:file_path]
          target_ns = schema_data["target_namespace"] || schema_data[:target_namespace]
          data = schema_data["schema_data"] || schema_data[:schema_data]

          serialized = SerializedSchema.new(
            file_path: file_path,
            target_namespace: target_ns,
            schema_data: data,
          )

          # Deserialize to Schema object
          schema = serialized.to_schema

          # Add to global processed schemas cache
          Lutaml::Xml::Schema::Xsd::Schema.schema_processed(file_path, schema)
        end
      end
    end
  end
end
