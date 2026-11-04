# frozen_string_literal: true

module Expressir
  module Express
    module Builders
      # Builds entity_decl nodes into Entity objects.
      class EntityDeclBuilder
        def call(ast_data)
          entity_head = ast_data[:entity_head]
          entity_body = ast_data[:entity_body]

          return nil unless entity_head

          id = Builder.build_optional(entity_head[:entity_id])
          subsuper = entity_head[:subsuper]

          abstract = false
          supertype_expression = nil
          subtype_of = []

          if subsuper.is_a?(Hash)
            supertype_constraint = subsuper[:supertype_constraint]
            subtype_declaration = subsuper[:subtype_declaration]

            if supertype_constraint.is_a?(Hash)
              abstract_entity = supertype_constraint[:abstract_entity_declaration]
              abstract_supertype = supertype_constraint[:abstract_supertype_declaration]
              supertype_rule = supertype_constraint[:supertype_rule]

              abstract = !abstract_entity.nil? || !abstract_supertype.nil?

              if supertype_rule.is_a?(Hash)
                supertype_expression = Builder.build({ supertype_rule: supertype_rule })
              elsif abstract_supertype.is_a?(Hash) && abstract_supertype[:subtype_constraint]
                subtype_constraint = abstract_supertype[:subtype_constraint]
                if subtype_constraint[:supertype_expression]
                  supertype_expression = Builder.build({ supertype_expression: subtype_constraint[:supertype_expression] })
                elsif subtype_constraint[:list_of_entity_ref]
                  entity_refs = Builder.build_children(Builder.ensure_array(subtype_constraint[:list_of_entity_ref][:entity_ref]).map do |d|
                    { entity_ref: d }
                  end)
                  supertype_expression = entity_refs.first if entity_refs.length == 1
                end
              end
            end

            if subtype_declaration.is_a?(Hash)
              list_ref = subtype_declaration[:list_of_entity_ref]
              # SUBTYPE OF (a) flattens to a Hash; SUBTYPE OF (a, b) to an
              # Array of single-key fragments (entity_ref possibly merged
              # with its op_comma). Collect entity_ref from either shape
              # (lutaml/expressir#341).
              raw_entity_refs =
                if list_ref.is_a?(Hash)
                  ref = list_ref[:entity_ref]
                  ref.is_a?(Array) ? ref : [ref]
                elsif list_ref.is_a?(Array)
                  list_ref.filter_map { |el| el[:entity_ref] if el.is_a?(Hash) }
                    .flat_map { |d| d.is_a?(Array) ? d : [d] }
                end
              if raw_entity_refs && !raw_entity_refs.empty?
                subtype_of = Builder.build_children(raw_entity_refs.map do |d|
                  { entity_ref: d }
                end)
              end
            end
          end

          attributes = []
          unique_rules = []
          where_rules = []

          if entity_body.is_a?(Hash)
            if entity_body[:explicit_attr]
              explicit_attrs = Builder.build_children(entity_body[:explicit_attr])
              attributes.concat(flatten_items(explicit_attrs))
            end

            if entity_body[:derive_clause]
              derived = Builder.build({ derive_clause: entity_body[:derive_clause] })
              attributes.concat(flatten_items(derived))
            end

            if entity_body[:inverse_clause]
              inverse = Builder.build({ inverse_clause: entity_body[:inverse_clause] })
              attributes.concat(flatten_items(inverse))
            end

            if entity_body[:unique_clause]
              built = Builder.build({ unique_clause: entity_body[:unique_clause] })
              unique_rules = Array(built).compact
            end
            unique_rules ||= []

            if entity_body[:where_clause]
              where_rules = Builder.build({ where_clause: entity_body[:where_clause] })
            end
            where_rules ||= []
          end

          entity_params = {
            id: id,
            supertype_expression: supertype_expression,
            subtype_of: subtype_of,
            attributes: attributes,
            unique_rules: flatten_items(unique_rules),
            where_rules: flatten_items(where_rules),
          }
          entity_params[:abstract] = true if abstract

          Expressir::Model::Declarations::Entity.new(**entity_params)
        end

        private

        # ExplicitAttrBuilder / DeriveClauseBuilder / InverseClauseBuilder
        # return Arrays (one node per declaration). Call sites must splice
        # those items into the parent list — nesting them leaves
        # `entity.attributes` as Array-of-Array, which formatters then
        # crash on (`undefined method 'kind' for an instance of Array`).
        # lutaml-model 0.8.107 no longer flattens collection assignments.
        def flatten_items(value)
          Array(value).flatten.compact
        end
      end
    end
  end
end
