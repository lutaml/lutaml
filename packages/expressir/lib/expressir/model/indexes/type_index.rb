# frozen_string_literal: true

module Expressir
  module Model
    module Indexes
      # Index for fast type lookup across schemas
      # Maintains indexes by qualified name, by schema, and by category
      class TypeIndex
        attr_reader :by_schema, :by_qualified_name, :by_category

        # Initialize a new type index
        # @param schemas [Array<Declarations::Schema>] Schemas to index
        def initialize(schemas = [])
          @by_schema = {}
          @by_qualified_name = {}
          @by_category = {}
          build(schemas) unless schemas.empty?
        end

        # Build indexes from schemas
        # @param schemas [Array<Declarations::Schema>] Schemas to index
        # @return [void]
        def build(schemas)
          @by_schema = {}
          @by_qualified_name = {}
          @by_category = {}

          schemas.each do |schema|
            schema_id = schema.id.safe_downcase
            @by_schema[schema_id] = {}

            next unless schema.types

            schema.types.each do |type|
              type_id = type.id.safe_downcase
              qualified_name = "#{schema_id}.#{type_id}"
              category = categorize(type)

              @by_schema[schema_id][type_id] = type
              @by_qualified_name[qualified_name] = type
              @by_category[category] ||= []
              @by_category[category] << type
            end
          end
        end

        # Find type by qualified name
        # @param qualified_name [String] Type qualified name (e.g., "schema.type")
        # @return [Declarations::Type, nil] Found type or nil
        def find(qualified_name)
          return nil if qualified_name.nil? || qualified_name.empty?

          normalized_name = qualified_name.safe_downcase

          # Try qualified name first
          type = @by_qualified_name[normalized_name]
          return type if type

          # Try as simple name across all schemas
          schema_name, type_name = normalized_name.split(".", 2)
          if type_name.nil?
            # Search all schemas for simple name
            @by_schema.each_value do |types|
              type = types[schema_name]
              return type if type
            end
          else
            # Look in specific schema
            schema_types = @by_schema[schema_name]
            return schema_types[type_name] if schema_types
          end

          nil
        end

        # List all types
        # @param schema [String, nil] Filter by schema name
        # @param category [String, nil] Filter by category
        # @return [Array<Declarations::Type>] List of types
        def list(schema: nil, category: nil)
          types = if schema
                    @by_schema[schema.safe_downcase]&.values || []
                  else
                    @by_qualified_name.values
                  end

          types = filter_by_category(types, category) if category

          types
        end

        # Check if index is empty
        # @return [Boolean] True if no types indexed
        def empty?
          @by_qualified_name.empty?
        end

        # Count total types
        # @return [Integer] Total number of types
        def count
          @by_qualified_name.size
        end

        # Get types for a specific schema
        # @param schema [String] Schema name
        # @return [Hash<String, Declarations::Type>] Types in schema
        def schema_types(schema)
          @by_schema[schema.safe_downcase] || {}
        end

        # Get types for a specific category
        # @param category [String] Category name
        # @return [Array<Declarations::Type>] Types in category
        def category_types(category)
          @by_category[category] || []
        end

        # Categorize type by its underlying type
        # @param type [Declarations::Type] Type to categorize
        # @return [String] Type category
        def categorize(type)
          return "defined" unless type.underlying_type

          underlying = type.underlying_type

          # Use explicit is_a? checks for test double compatibility
          return "select" if underlying.is_a?(DataTypes::Select)
          return "enumeration" if underlying.is_a?(DataTypes::Enumeration)
          return "aggregate" if underlying.is_a?(DataTypes::Array) ||
            underlying.is_a?(DataTypes::Bag) ||
            underlying.is_a?(DataTypes::List) ||
            underlying.is_a?(DataTypes::Set)

          "defined"
        end

        private

        # Filter types by category
        # @param types [Array<Declarations::Type>] List of types
        # @param category [String] Category to filter by
        # @return [Array<Declarations::Type>] Filtered types
        def filter_by_category(types, category)
          types.select { |type| categorize(type) == category }
        end
      end
    end
  end
end
