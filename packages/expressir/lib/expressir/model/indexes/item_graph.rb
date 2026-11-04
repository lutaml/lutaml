# frozen_string_literal: true

module Expressir
  module Model
    module Indexes
      # Item-level graph over a resolved repository: nodes are schema
      # items (canonical "schema.item" paths), edges are inheritance,
      # interface imports, and attribute-type references.
      #
      # {Model::ModelElement#path} is file-qualified and empty for
      # id-less nodes, so node identity is the last two path segments —
      # unique because schema names are unique within a repository.
      class ItemGraph
        attr_reader :nodes, :subtype_of, :dependencies

        # @param repository [Repository] a resolved repository
        def initialize(repository)
          @nodes = {}
          @subtype_of = Hash.new { |h, k| h[k] = [] }
          @dependencies = Hash.new { |h, k| h[k] = [] }
          build(repository)
        end

        # Plain tables for artifact persistence — node keys only, no
        # model references. `ItemGraph.from_tables` is the zero-model
        # counterpart used on warm loads.
        def tables
          {
            "nodes" => @nodes.keys,
            "subtype_of" => @subtype_of.reject { |_, parents| parents.empty? },
            "dependencies" => @dependencies.reject { |_, deps| deps.empty? },
          }
        end

        def self.from_tables(tables)
          graph = allocate
          graph.instance_variable_set(:@nodes, tables["nodes"].to_h { |k| [k, nil] })
          graph.instance_variable_set(
            :@subtype_of,
            Hash.new { |h, k| h[k] = [] }.update(tables["subtype_of"] || {}),
          )
          graph.instance_variable_set(
            :@dependencies,
            Hash.new { |h, k| h[k] = [] }.update(tables["dependencies"] || {}),
          )
          graph
        end

        def include?(path)
          @nodes.key?(canonical(path))
        end

        # Transitive supertype closure of an entity, breadth-first.
        def supertypes(path)
          key = canonical(path)
          return [] unless @nodes.key?(key)

          seen = {}
          result = []
          queue = @subtype_of[key].dup
          until queue.empty?
            current = queue.shift
            next if seen[current]

            seen[current] = true
            result << current
            queue.concat(@subtype_of[current])
          end
          result
        end

        # Schemas whose items `schema` imports (USE FROM / REFERENCE
        # FROM), direct only. Accepts a schema object or its id.
        def dependencies_of(schema)
          schema_id = schema.respond_to?(:id) ? schema.id : schema.to_s
          @dependencies[schema_id.safe_downcase].dup
        end

        def subtype_edges
          @subtype_of.flat_map { |child, parents| parents.map { |p| [child, p] } }
        end

        # Direct subtypes of an entity (the inverse of subtype_of).
        def subtypes(path)
          key = canonical(path)
          return [] unless @nodes.key?(key)

          @subtype_of.select { |_child, parents| parents.include?(key) }.keys
        end

        # Transitive subtype closure of an entity (everything below it
        # in the hierarchy), breadth-first and cycle-safe.
        def transitive_subtypes(path)
          key = canonical(path)
          return [] unless @nodes.key?(key)

          seen = {}
          queue = subtypes(key)
          until queue.empty?
            current = queue.shift
            next if seen[current]

            seen[current] = true
            queue.concat(subtypes(current))
          end
          seen.keys
        end

        # Transitive interface closure of a schema — every schema it
        # depends on, directly or through intermediates. Cycle-safe.
        def dependency_closure(schema)
          schema_id = schema.respond_to?(:id) ? schema.id : schema.to_s
          seen = {}
          queue = dependencies_of(schema_id).dup
          until queue.empty?
            current = queue.shift
            next if seen[current]

            seen[current] = true
            queue.concat(@dependencies[current] || [])
          end
          seen.keys
        end

        # Schemas that import `schema` (USE FROM / REFERENCE FROM it),
        # direct only — the "used by" direction for doc generation.
        def dependents_of(schema)
          schema_id = schema.respond_to?(:id) ? schema.id : schema.to_s
          key = schema_id.safe_downcase
          @dependencies.select { |_from, deps| deps.include?(key) }.keys
        end

        def cross_schema_subtype_edges
          subtype_edges.count { |child, parent| child.split(".")[0] != parent.split(".")[0] }
        end

        private

        def canonical(path)
          return nil unless path

          parts = path.to_s.split(".")
          return nil if parts.size < 2

          parts[-2, 2].join(".").safe_downcase
        end

        def build(repository)
          # Nodes register before their subtype edges: subtype references
          # may be unresolved (the declaring schema is not in the
          # repository), and an edge to a node that does not exist would
          # surface as a phantom path in supertype closures.
          edges = []
          repository.schemas.each do |schema|
            schema_id = schema.id.safe_downcase
            schema.entities.to_a.each do |entity|
              key = node_key(schema_id, entity)
              @nodes[key] = entity
              edges << [key, schema_id, entity]
            end
            schema.types.to_a.each do |type|
              @nodes[node_key(schema_id, type)] = type
            end
            schema.interfaces.to_a.each do |interface|
              target = interface.schema.is_a?(String) ? interface.schema : interface.schema&.id
              next unless target

              @dependencies[schema_id] << target.safe_downcase
            end
          end
          edges.each do |key, schema_id, entity|
            entity.subtype_of.to_a.each do |ref|
              parent = ref.base_path ? canonical(ref.base_path) : "#{schema_id}.#{ref.id.safe_downcase}"
              @subtype_of[key] << parent if parent && @nodes.key?(parent)
            end
          end
        end

        def node_key(schema_id, element)
          canonical(element.path) || "#{schema_id}.#{element.id.safe_downcase}"
        end
      end
    end
  end
end
