# frozen_string_literal: true

module Expressir
  module Model
    module Indexes
      # Index for cross-schema reference tracking
      # Maintains USE FROM, REFERENCE FROM relationships and dependency graphs
      class ReferenceIndex
        attr_reader :use_from, :reference_from, :dependencies

        # Initialize a new reference index
        # @param schemas [Array<Declarations::Schema>] Schemas to index
        def initialize(schemas = [])
          @use_from = {}
          @reference_from = {}
          @dependencies = {}
          build(schemas) unless schemas.empty?
        end

        # Build indexes from schemas
        # @param schemas [Array<Declarations::Schema>] Schemas to index
        # @return [void]
        def build(schemas)
          @use_from = {}
          @reference_from = {}
          @dependencies = {}

          schemas.each do |schema|
            schema_id = schema.id.safe_downcase

            # Initialize schema entries even if there are no interfaces
            @use_from[schema_id] = []
            @reference_from[schema_id] = []

            next unless schema.interfaces

            schema.interfaces.each do |interface|
              referenced_schema = interface.schema.id.safe_downcase
              items = interface.items.map { |item| item.ref.id }

              if interface.kind == Declarations::Interface::USE
                @use_from[schema_id] << {
                  schema: referenced_schema,
                  items: items,
                }
              elsif interface.kind == Declarations::Interface::REFERENCE
                @reference_from[schema_id] << {
                  schema: referenced_schema,
                  items: items,
                }
              end

              @dependencies[schema_id] ||= Set.new
              @dependencies[schema_id] << referenced_schema
            end
          end
        end

        # Get USE FROM references for a schema
        # @param schema [String] Schema name
        # @return [Array<Hash>] List of USE FROM references
        def use_references(schema)
          @use_from[schema.safe_downcase] || []
        end

        # Get REFERENCE FROM references for a schema
        # @param schema [String] Schema name
        # @return [Array<Hash>] List of REFERENCE FROM references
        def reference_references(schema)
          @reference_from[schema.safe_downcase] || []
        end

        # Get all dependencies for a schema
        # @param schema [String] Schema name
        # @return [Set<String>] Set of dependent schema names
        def schema_dependencies(schema)
          @dependencies[schema.safe_downcase] || Set.new
        end

        # Detect circular dependencies in schema references
        # @return [Array<Array<String>>] List of circular dependency cycles
        def detect_circular_dependencies
          cycles = []
          visited = Set.new
          rec_stack = Set.new

          @dependencies.each_key do |schema_id|
            next if visited.include?(schema_id)

            path = []
            detect_cycle(schema_id, visited, rec_stack, path, cycles)
          end

          cycles
        end

        # Check if index is empty
        # @return [Boolean] True if no references indexed
        def empty?
          @dependencies.empty?
        end

        # Count total USE FROM references
        # @return [Integer] Total USE FROM references
        def use_from_count
          @use_from.values.sum(&:size)
        end

        # Count total REFERENCE FROM references
        # @return [Integer] Total REFERENCE FROM references
        def reference_from_count
          @reference_from.values.sum(&:size)
        end

        private

        # Helper method for cycle detection using DFS
        # @param node [String] Current schema node
        # @param visited [Set] Set of visited nodes
        # @param rec_stack [Set] Recursion stack for current path
        # @param path [Array] Current path
        # @param cycles [Array] Accumulated cycles
        # @return [Boolean] True if cycle detected
        def detect_cycle(node, visited, rec_stack, path, cycles)
          visited << node
          rec_stack << node
          path << node

          deps = @dependencies[node] || Set.new
          deps.each do |dep|
            if !visited.include?(dep)
              return true if detect_cycle(dep, visited, rec_stack, path, cycles)
            elsif rec_stack.include?(dep)
              # Found a cycle
              cycle_start = path.index(dep)
              cycles << (path[cycle_start..] + [dep])
              return true
            end
          end

          path.pop
          rec_stack.delete(node)
          false
        end
      end
    end
  end
end
