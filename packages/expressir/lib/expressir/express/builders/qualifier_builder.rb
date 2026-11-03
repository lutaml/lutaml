# frozen_string_literal: true

module Expressir
  module Express
    module Builders
      # Builds qualifier nodes (attribute, group, index qualifiers).
      class QualifierBuilder
        def build_redeclared_attribute(ast_data)
          qualified_attr = ast_data[:qualified_attribute]
          if qualified_attr.is_a?(Hash)
            Builder.build({ qualified_attribute: qualified_attr })
          end
        end

        def build_referenced_attribute(ast_data)
          if ast_data[:attribute_ref]
            Builder.build({ attribute_ref: ast_data[:attribute_ref] })
          elsif ast_data[:qualified_attribute]
            Builder.build({ qualified_attribute: ast_data[:qualified_attribute] })
          end
        end

        def build_qualified_attribute(ast_data)
          # t_self is part of qualified_attribute grammar
          self_ref = if ast_data[:t_self]
                       Expressir::Model::References::SimpleReference.new(id: "SELF")
                     end

          # group_qualifier contains the entity reference
          entity_ref = if ast_data[:group_qualifier]
                         Builder.build({ entity_ref: ast_data[:group_qualifier][:entity_ref] })
                       end

          # Create GroupReference with ref (SELF) and entity
          group_qual = if self_ref || entity_ref
                         Expressir::Model::References::GroupReference.new(
                           ref: self_ref, entity: entity_ref,
                         )
                       end

          attr_qual = if ast_data[:attribute_qualifier]
                        Builder.build({ attribute_qualifier: ast_data[:attribute_qualifier] })
                      end

          if group_qual && attr_qual
            Expressir::Model::References::AttributeReference.new(
              ref: group_qual, attribute: attr_qual,
            )
          else
            attr_qual || group_qual
          end
        end

        def build_group_qualifier(ast_data)
          entity = if ast_data[:entity_ref]
                     Builder.build({ entity_ref: ast_data[:entity_ref] })
                   end
          Expressir::Model::References::GroupReference.new(entity: entity)
        end

        def build_attribute_qualifier(ast_data)
          Builder.build({ attribute_ref: ast_data[:attribute_ref] })
        end

        def build_index_qualifier(ast_data)
          index1 = Builder.build_optional(ast_data[:index1])
          index2 = Builder.build_optional(ast_data[:index2])
          Expressir::Model::References::IndexReference.new(index1: index1,
                                                           index2: index2)
        end

        def build_index1(ast_data)
          Builder.build_optional(ast_data[:numeric_expression])
        end

        def build_index2(ast_data)
          Builder.build_optional(ast_data[:numeric_expression])
        end

        def build_index(ast_data)
          Builder.build_optional(ast_data[:numeric_expression])
        end

        def build_enumeration_reference(ast_data)
          type_ref = Builder.build_optional(ast_data[:type_ref])
          enum_ref = if ast_data[:enumeration_ref]
                       Builder.build({ enumeration_ref: ast_data[:enumeration_ref] })
                     end

          if type_ref && enum_ref
            Expressir::Model::References::AttributeReference.new(
              ref: type_ref,
              attribute: enum_ref,
            )
          elsif enum_ref
            enum_ref
          end
        end
      end
    end
  end
end
