# frozen_string_literal: true

module Expressir
  module Express
    module Builders
      # Builds inverse_attr nodes.
      class InverseAttrBuilder
        def call(ast_data)
          attr_decl_data = ast_data[:attribute_decl]
          attr = if attr_decl_data.is_a?(Hash)
                   Builder.build({ attribute_decl: attr_decl_data })
                 end

          type_data = ast_data[:inverse_attr_type]
          type = if type_data.is_a?(Hash)
                   Builder.build({ inverse_attr_type: type_data })
                 end

          expression = if ast_data[:entity_ref]
                         ref = Builder.build({ entity_ref: ast_data[:entity_ref] })
                         attr_ref = if ast_data[:attribute_ref]
                                      Builder.build({ attribute_ref: ast_data[:attribute_ref] })
                                    end
                         Expressir::Model::References::AttributeReference.new(ref: ref,
                                                                              attribute: attr_ref)
                       else
                         attr_ref_data = ast_data[:attribute_ref]
                         if attr_ref_data
                           Builder.build({ attribute_ref: attr_ref_data })
                         end
                       end

          Expressir::Model::Declarations::InverseAttribute.new(
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
