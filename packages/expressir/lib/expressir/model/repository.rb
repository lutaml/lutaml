# frozen_string_literal: true

module Expressir
  module Model
    # Multi-schema global scope with enhanced repository features
    # Focuses on schema management and delegates indexing/validation to specialized classes
    #
    # A Repository contains multiple ExpFile instances (one per parsed .exp file).
    #
    # Structure:
    #   Repository
    #   └── files: [ExpFile, ...]
    #       └── ExpFile (path: "a.exp")
    #           ├── untagged_remarks: [...]  # file-level preamble
    #           └── schemas: [SchemaA]
    class Repository < ModelElement
      # Internal storage for schemas (used for direct manipulation)
      attribute :files, ExpFile, collection: true, initialize_empty: true
      attribute :_class, :string, default: -> { self.class.name }

      # Base directory for schema files
      attr_accessor :base_dir

      # Index instances (lazy-loaded)
      attr_reader :entity_index, :type_index, :reference_index

      # Item-level graph; loaded from the compiled-set artifact on
      # warm starts, built on demand otherwise.
      attr_accessor :item_graph

      # Restore deserialized indexes (used by Package::Reader)
      def restore_indexes(entity_index: nil, type_index: nil,
reference_index: nil)
        @entity_index = entity_index if entity_index
        @type_index = type_index if type_index
        @reference_index = reference_index if reference_index
      end

      # Internal schema storage for direct manipulation
      attr_reader :_schemas

      key_value do
        map "_class", to: :_class, render_default: true
        map "files", to: :files
      end

      liquid do
        map :schemas, to: :schemas
      end

      def initialize(*, base_dir: nil, schemas: nil, **)
        super(*, **)
        @base_dir = base_dir
        @entity_index = nil
        @type_index = nil
        @reference_index = nil
        @_schemas = []

        # Support direct schemas initialization
        schemas&.each { |schema| @_schemas << schema }
      end

      # Get all schemas (from both files and direct storage).
      # Files that failed to parse are nil in `files` — a parse failure must
      # not crash schema enumeration with a NoMethodError from in here.
      # @return [Array<Declarations::Schema>]
      def schemas
        file_schemas = files.compact.flat_map(&:schemas).compact
        file_schemas + @_schemas
      end

      # Alias for schemas
      # @return [Array<Declarations::Schema>]
      def all_schemas
        schemas
      end

      # Add a schema to the repository
      # @param schema [Declarations::Schema] Schema to add
      def add_schema(schema)
        return unless schema

        @_schemas << schema
      end

      # @return [Array<Declarations::Schema>]
      def children
        schemas
      end

      # Build indexes for entities, types, and references
      # @return [void]
      def build_indexes
        target_schemas = all_schemas
        @entity_index = Indexes::EntityIndex.new(target_schemas)
        @type_index = Indexes::TypeIndex.new(target_schemas)
        @reference_index = Indexes::ReferenceIndex.new(target_schemas)
      end

      # Find entity by qualified name
      # @param qualified_name [String] Entity qualified name (e.g., "action_schema.action")
      # @return [Declarations::Entity, nil] Found entity or nil
      def find_entity(qualified_name:)
        ensure_indexes_built
        @entity_index.find(qualified_name)
      end

      # Find type by qualified name
      # @param qualified_name [String] Type qualified name
      # @return [Declarations::Type, nil] Found type or nil
      def find_type(qualified_name:)
        ensure_indexes_built
        @type_index.find(qualified_name)
      end

      # List all entities
      # @param schema [String, nil] Filter by schema name
      # @param format [Symbol] Output format (:object, :hash, :json, :yaml)
      # @return [Array] List of entities
      def list_entities(schema: nil, format: :object)
        ensure_indexes_built

        entities = @entity_index.list(schema: schema)

        format_output(entities, format) do |entity|
          { id: entity.id, schema: entity.parent.id, path: entity.path }
        end
      end

      # List all types
      # @param schema [String, nil] Filter by schema name
      # @param category [String, nil] Filter by type category (select, enumeration, etc.)
      # @param format [Symbol] Output format (:object, :hash, :json, :yaml)
      # @return [Array] List of types
      def list_types(schema: nil, category: nil, format: :object)
        ensure_indexes_built

        types = @type_index.list(schema: schema, category: category)

        format_output(types, format) do |type|
          { id: type.id, schema: type.parent.id, path: type.path,
            category: @type_index.categorize(type) }
        end
      end

      # Resolve all references across schemas
      # Uses the existing ResolveReferencesModelVisitor
      # @return [void]
      def resolve_all_references
        visitor = Expressir::Express::ResolveReferencesModelVisitor.new
        visitor.visit(self)
      end

      # Validate repository consistency
      # @param strict [Boolean] Enable strict validation
      # @return [Hash] Validation results with :valid?, :errors, :warnings
      def validate(strict: false)
        ensure_indexes_built
        validator = RepositoryValidator.new(all_schemas, @reference_index)
        validator.validate(strict: strict)
      end

      # Get statistics
      # @param format [Symbol] Output format (:hash, :json, :yaml)
      # @return [Hash, String] Repository statistics
      def statistics(format: :hash)
        ensure_indexes_built

        stats = {
          total_schemas: all_schemas.size,
          total_entities: count_entities,
          total_types: count_types,
          total_functions: count_functions,
          total_rules: count_rules,
          total_procedures: count_procedures,
          entities_by_schema: entities_by_schema_counts,
          types_by_category: types_by_category_counts,
          interfaces: interface_counts,
        }

        case format
        when :json
          require "json"
          stats.to_json
        when :yaml
          require "yaml"
          stats.to_yaml
        else
          stats
        end
      end

      # Group schemas by category based on their contents
      # @return [Hash] Hash with category keys and schema arrays
      def schemas_by_category
        target_schemas = all_schemas
        {
          with_entities: target_schemas.select { |s| s.entities&.any? },
          with_types: target_schemas.select { |s| s.types&.any? },
          with_functions: target_schemas.select { |s| s.functions&.any? },
          with_rules: target_schemas.select { |s| s.rules&.any? },
          interface_only: target_schemas.select do |s|
            s.interfaces&.any? && !s.entities&.any? && !s.types&.any?
          end,
          empty: target_schemas.select do |s|
            !s.entities&.any? && !s.types&.any? && !s.functions&.any?
          end,
        }
      end

      # Get largest schemas by total element count
      # @param limit [Integer] Maximum number of schemas to return
      # @return [Array<Hash>] Array of hashes with :schema and :total_elements
      def largest_schemas(limit = 10)
        all_schemas.map do |s|
          {
            schema: s,
            total_elements: count_schema_elements(s),
          }
        end.sort_by { |item| -item[:total_elements] }.take(limit)
      end

      # Calculate schema complexity score
      # Entities=2, Types=1, Functions=3, Procedures=3, Rules=4, Interfaces=2
      # @param schema [Declarations::Schema] Schema to analyze
      # @return [Integer] Complexity score
      def schema_complexity(schema)
        score = 0
        score += (schema.entities&.size || 0) * 2
        score += (schema.types&.size || 0) * 1
        score += (schema.functions&.size || 0) * 3
        score += (schema.procedures&.size || 0) * 3
        score += (schema.rules&.size || 0) * 4
        score += (schema.interfaces&.size || 0) * 2
        score
      end

      # Get schemas sorted by complexity
      # @param limit [Integer] Maximum number of schemas to return
      # @return [Array<Hash>] Array of hashes with :schema and :complexity
      def schemas_by_complexity(limit = 10)
        all_schemas.map { |s| { schema: s, complexity: schema_complexity(s) } }
          .sort_by { |item| -item[:complexity] }
          .take(limit)
      end

      # Get dependency statistics
      # @return [Hash] Statistics about interface dependencies
      def dependency_statistics
        stats = {
          total_interfaces: 0,
          use_from_count: 0,
          reference_from_count: 0,
          most_referenced: [],
          most_dependent: [],
        }

        reference_counts = Hash.new(0)
        dependency_counts = Hash.new(0)

        all_schemas.each do |schema|
          next unless schema.interfaces&.any?

          stats[:total_interfaces] += schema.interfaces.size
          dependency_counts[schema.id] = schema.interfaces.size

          schema.interfaces.each do |interface|
            stats[:use_from_count] += 1 if interface.kind == Declarations::Interface::USE
            stats[:reference_from_count] += 1 if interface.kind == Declarations::Interface::REFERENCE
            reference_counts[interface.schema.id] += 1 if interface.schema
          end
        end

        stats[:most_referenced] = reference_counts.sort_by do |_, v|
          -v
        end.take(10).to_h
        stats[:most_dependent] = dependency_counts.sort_by do |_, v|
          -v
        end.take(10).to_h

        stats
      end

      # Generate SchemaManifest from repository
      # @return [SchemaManifest] Manifest describing all schemas
      def to_manifest
        manifest = Expressir::SchemaManifest.new
        all_schemas.each do |schema|
          manifest.schemas << Expressir::SchemaManifestEntry.new(
            id: schema.id,
            path: schema.file || "#{schema.id}.exp",
          )
        end
        manifest
      end

      # Build repository from list of schema files
      # @param file_paths [Array<String>] Schema file paths
      # @param base_dir [String, nil] Base directory for path resolution
      # @param max_processes [Integer, nil] parse in a fork worker pool when
      #   set above 1 on a fork-capable platform (advisory; degrades to
      #   sequential otherwise). Unlike Express::Parser.from_files, a file
      #   that fails to parse always raises.
      # @return [Repository] Built repository with all schemas
      def self.from_files(file_paths, base_dir: nil, max_processes: nil)
        repo = new(base_dir: base_dir)

        pool = Expressir::Express::ParallelFiles
        parsed_files = if pool.sequential?(file_paths, max_processes)
                         file_paths.map do |path|
                           Expressir::Express::Parser.from_file(path)
                         end
                       else
                         pool.run(file_paths,
                                  parse: ->(path) { Expressir::Express::Parser.from_file(path) },
                                  max_processes: max_processes,
                                  strict: true)
                       end

        parsed_files.each do |parsed|
          repo.files << parsed if parsed.is_a?(ExpFile)
        end

        repo.resolve_all_references
        repo
      end

      # Load repository from LER package
      # @param package_path [String] Path to .ler package file
      # @return [Repository] Loaded repository
      def self.from_package(package_path)
        Package::Reader.load(package_path)
      end

      # Export repository to LER package
      # @param output_path [String] Path for output .ler file
      # @param options [Hash] Package options
      # @option options [String] :name Package name
      # @option options [String] :version Package version
      # @option options [String] :description Package description
      # @option options [String] :express_mode ('include_all') Bundling mode
      # @option options [String] :resolution_mode ('resolved') Resolution mode
      # @option options [String] :serialization_format ('marshal') Serialization format
      # @return [String] Path to created package
      def export_to_package(output_path, options = {})
        builder = Package::Builder.new
        builder.build(self, output_path, options)
      end

      private

      # Count total elements in schema
      # @param schema [Declarations::Schema] Schema to count elements from
      # @return [Integer] Total count of all elements
      def count_schema_elements(schema)
        (schema.entities&.size || 0) +
          (schema.types&.size || 0) +
          (schema.functions&.size || 0) +
          (schema.procedures&.size || 0) +
          (schema.rules&.size || 0) +
          (schema.constants&.size || 0)
      end

      # Ensure indexes are built before use
      # @return [void]
      def ensure_indexes_built
        build_indexes if @entity_index.nil? || @entity_index.empty?
      end

      # Format output based on requested format
      # @param items [Array] Items to format
      # @param format [Symbol] Output format
      # @yield [item] Block to convert item to hash
      # @return [Array, String] Formatted output
      def format_output(items, format, &)
        case format
        when :hash
          items.map(&)
        when :json
          require "json"
          items.map(&).to_json
        when :yaml
          require "yaml"
          items.map(&).to_yaml
        else
          items
        end
      end

      # Count entities by schema
      # @return [Hash<String, Integer>] Entity counts per schema
      def entities_by_schema_counts
        counts = {}
        all_schemas.each do |schema|
          counts[schema.id] = schema.entities&.size || 0
        end
        counts
      end

      # Count types by category
      # @return [Hash<Symbol, Integer>] Type counts per category
      def types_by_category_counts
        counts = {
          select: 0,
          enumeration: 0,
          aggregate: 0,
          defined: 0,
        }

        all_schemas.each do |schema|
          next unless schema.types

          schema.types.each do |type|
            category = @type_index.categorize(type).to_sym
            counts[category] ||= 0
            counts[category] += 1
          end
        end

        counts
      end

      # Count interfaces by type
      # @return [Hash<Symbol, Integer>] Interface counts
      def interface_counts
        counts = {
          use_from: 0,
          reference_from: 0,
        }

        all_schemas.each do |schema|
          next unless schema.interfaces

          schema.interfaces.each do |interface|
            if interface.kind == Declarations::Interface::USE
              counts[:use_from] += 1
            elsif interface.kind == Declarations::Interface::REFERENCE
              counts[:reference_from] += 1
            end
          end
        end

        counts
      end

      # Count total entities across all schemas
      # Uses indexes if available, falls back to schemas collection
      # @return [Integer] Total entity count
      def count_entities
        return @entity_index.count if @entity_index && !@entity_index.empty?

        all_schemas.sum { |schema| schema.entities&.size || 0 }
      end

      # Count total types across all schemas
      # Uses indexes if available, falls back to schemas collection
      # @return [Integer] Total type count
      def count_types
        return @type_index.count if @type_index && !@type_index.empty?

        all_schemas.sum { |schema| schema.types&.size || 0 }
      end

      # Count total functions across all schemas
      # @return [Integer] Total function count
      def count_functions
        all_schemas.sum { |schema| schema.functions&.size || 0 }
      end

      # Count total rules across all schemas
      # @return [Integer] Total rule count
      def count_rules
        all_schemas.sum { |schema| schema.rules&.size || 0 }
      end

      # Count total procedures across all schemas
      # @return [Integer] Total procedure count
      def count_procedures
        all_schemas.sum { |schema| schema.procedures&.size || 0 }
      end
    end
  end
end
