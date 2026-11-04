# frozen_string_literal: true

module Expressir
  module Model
    module Indexes
      # Index for fast entity lookup across schemas
      # Maintains indexes by qualified name and by schema for efficient querying
      class EntityIndex
        attr_reader :by_schema, :by_qualified_name

        # Initialize a new entity index
        # @param schemas [Array<Declarations::Schema>] Schemas to index
        def initialize(schemas = [])
          @by_schema = {}
          @by_qualified_name = {}
          build(schemas) unless schemas.empty?
        end

        # Build indexes from schemas
        # @param schemas [Array<Declarations::Schema>] Schemas to index
        # @return [void]
        def build(schemas)
          @by_schema = {}
          @by_qualified_name = {}

          schemas.each do |schema|
            schema_id = schema.id.safe_downcase
            @by_schema[schema_id] = {}

            next unless schema.entities

            schema.entities.each do |entity|
              entity_id = entity.id.safe_downcase
              qualified_name = "#{schema_id}.#{entity_id}"

              @by_schema[schema_id][entity_id] = entity
              @by_qualified_name[qualified_name] = entity
            end
          end
        end

        # Find entity by qualified name
        # @param qualified_name [String] Entity qualified name (e.g., "schema.entity")
        # @return [Declarations::Entity, nil] Found entity or nil
        def find(qualified_name)
          return nil if qualified_name.nil? || qualified_name.empty?

          normalized_name = qualified_name.safe_downcase

          # Try qualified name first
          entity = @by_qualified_name[normalized_name]
          return entity if entity

          # Try as simple name across all schemas
          schema_name, entity_name = normalized_name.split(".", 2)
          if entity_name.nil?
            # Search all schemas for simple name
            @by_schema.each_value do |entities|
              entity = entities[schema_name]
              return entity if entity
            end
          else
            # Look in specific schema
            schema_entities = @by_schema[schema_name]
            return schema_entities[entity_name] if schema_entities
          end

          nil
        end

        # List all entities
        # @param schema [String, nil] Filter by schema name
        # @return [Array<Declarations::Entity>] List of entities
        def list(schema: nil)
          if schema
            @by_schema[schema.safe_downcase]&.values || []
          else
            @by_qualified_name.values
          end
        end

        # Check if index is empty
        # @return [Boolean] True if no entities indexed
        def empty?
          @by_qualified_name.empty?
        end

        # Count total entities
        # @return [Integer] Total number of entities
        def count
          @by_qualified_name.size
        end

        # Get entities for a specific schema
        # @param schema [String] Schema name
        # @return [Hash<String, Declarations::Entity>] Entities in schema
        def schema_entities(schema)
          @by_schema[schema.safe_downcase] || {}
        end
      end
    end
  end
end
