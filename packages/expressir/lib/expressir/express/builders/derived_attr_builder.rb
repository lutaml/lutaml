# frozen_string_literal: true

module Expressir
  module Express
    module Builders
      # Builds derived_attr nodes.
      class DerivedAttrBuilder
        def call(ast_data)
          attr_decl_data = ast_data[:attribute_decl]
          attr = if attr_decl_data.is_a?(Hash)
                   Builder.build({ attribute_decl: attr_decl_data })
                 end
          type = Builder.build_optional(ast_data[:parameter_type])
          expression = if ast_data[:expression]
                         Builder.build({ expression: ast_data[:expression] })
                       end

          Expressir::Model::Declarations::DerivedAttribute.new(
            id: attr&.id,
            supertype_attribute: attr&.supertype_attribute,
            type: type,
            expression: expression,
          )
        end
      end
    end
  end
end
