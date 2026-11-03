# frozen_string_literal: true

module Expressir
  module Express
    # Semantic change classification (TODO.compat/06): SchemaCompare
    # deltas classified breaking vs additive through the subtype
    # graph, with the ISO 10303-11 Annex K deprecation policy applied.
    #
    # Rules:
    # - :added → additive (a new declaration, subtype or attribute
    #   extends the schema without constraining existing instances).
    # - :removed → breaking; the subtype graph names every direct
    #   subtype that loses the declaration. When the path is in the
    #   deprecation set the removal is the Annex K announced transition
    #   (flagged `deprecated`, still classified breaking).
    # - :changed → breaking (a signature change constrains consumers);
    #   flagged deprecated when the path is in the deprecation set.
    module ChangeClassification
      BREAKING = "breaking"
      ADDITIVE = "additive"

      Verdict = Struct.new(:value, :deprecated, :affected_subtypes,
                           keyword_init: true)

      module_function

      # @param deprecated [Array<String>] schema.ELEMENT paths the
      #   schema edition already announced for removal (Annex K)
      def apply(deltas, base_schema, deprecated: [])
        graph = subtype_map(base_schema)
        announced = deprecated.map(&:safe_downcase).to_h { |p| [p, true] }
        deltas.each do |delta|
          delta.classification = verdict(delta, graph, announced)
        end
        deltas
      end

      def verdict(delta, graph, announced)
        path = delta.path.safe_downcase
        # attribute-level deltas (schema.entity.attr) inherit the
        # owning entity's subtype reach
        owner = path.split(".").first(2).join(".")
        case delta.op
        when :added
          Verdict.new(value: ADDITIVE, deprecated: false,
                      affected_subtypes: [])
        else
          Verdict.new(
            value: BREAKING,
            deprecated: announced.key?(path),
            affected_subtypes: Array(graph[owner]),
          )
        end
      end

      # Direct subtypes per entity, schema-qualified to match delta
      # paths, from the base schema's subtype_of references.
      def subtype_map(schema)
        map = Hash.new { |hash, key| hash[key] = [] }
        schema_id = schema.id&.safe_downcase
        Array(schema.entities).each do |entity|
          next unless entity.id

          Array(entity.subtype_of).each do |ref|
            name = ref.respond_to?(:id) ? ref.id : ref
            next unless name

            map["#{schema_id}.#{name.safe_downcase}"] << entity.id.safe_downcase
          end
        end
        map
      end
    end
  end
end
