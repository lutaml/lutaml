# frozen_string_literal: true

module Expressir
  module Express
    module Builders
      # Builds inverse_attr_type nodes.
      class InverseAttrTypeBuilder
        def call(ast_data)
          bound_spec = ast_data[:bound_spec] || {}
          bound1 = Builder.build_optional(bound_spec[:bound1])
          bound2 = Builder.build_optional(bound_spec[:bound2])
          base_type_data = ast_data[:entity_ref]
          base_type = if base_type_data.is_a?(Hash)
                        Builder.build({ entity_ref: base_type_data })
                      end

          if ast_data[:t_set]
            Expressir::Model::DataTypes::Set.new(bound1: bound1,
                                                 bound2: bound2, base_type: base_type)
          elsif ast_data[:t_bag]
            Expressir::Model::DataTypes::Bag.new(bound1: bound1,
                                                 bound2: bound2, base_type: base_type)
          else
            base_type
          end
        end
      end
    end
  end
end
