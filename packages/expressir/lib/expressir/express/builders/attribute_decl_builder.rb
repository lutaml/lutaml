# frozen_string_literal: true

module Expressir
  module Express
    module Builders
      # Builds attribute_decl nodes.
      class AttributeDeclBuilder
        def call(ast_data)
          id = Builder.build_optional(ast_data[:attribute_id])
          supertype_attribute = nil

          if ast_data[:redeclared_attribute].is_a?(Hash)
            redeclared = ast_data[:redeclared_attribute]
            if redeclared[:qualified_attribute].is_a?(Hash)
              supertype_attribute = Builder.build({ qualified_attribute: redeclared[:qualified_attribute] })

              if supertype_attribute.is_a?(Expressir::Model::References::AttributeReference)
                id ||= supertype_attribute.attribute&.id
              end
            end
            id = Builder.build_optional(redeclared[:attribute_id]) if redeclared[:attribute_id]
          end

          Expressir::Model::Declarations::Attribute.new(
            id: id,
            supertype_attribute: supertype_attribute,
          )
        end
      end
    end
  end
end
