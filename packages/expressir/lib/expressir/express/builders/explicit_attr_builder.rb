# frozen_string_literal: true

module Expressir
  module Express
    module Builders
      # Builds explicit_attr nodes.
      class ExplicitAttrBuilder
        def call(ast_data)
          list_data = ast_data[:list_of_attribute_decl]
          attr_decl_data = if list_data.is_a?(Hash)
                             list_data[:attribute_decl]
                           elsif list_data.is_a?(Array)
                             list_data.filter_map do |item|
                               item[:attribute_decl] if item.is_a?(Hash)
                             end
                           else
                             ast_data[:attribute_decl]
                           end
          attr_decls = Builder.ensure_array(attr_decl_data)
          optional = !ast_data[:t_optional].nil?
          type = Builder.build_optional(ast_data[:parameter_type])

          attrs = attr_decls.map do |attr_data|
            Builder.build({ attribute_decl: attr_data })
          end

          attrs.map do |attr|
            next attr unless attr.is_a?(Expressir::Model::Declarations::Attribute)

            attr_params = {
              id: attr.id,
              kind: Expressir::Model::Declarations::Attribute::EXPLICIT,
              supertype_attribute: attr.supertype_attribute,
              type: type,
            }
            attr_params[:optional] = true if optional
            # Preserve source information from the intermediate object
            attr_params[:source] = attr.source if attr.source
            if attr.source_offset
              attr_params[:source_offset] =
                attr.source_offset
            end
            Expressir::Model::Declarations::Attribute.new(**attr_params)
          end
        end
      end
    end
  end
end
