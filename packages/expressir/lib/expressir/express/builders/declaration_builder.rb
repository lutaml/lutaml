# frozen_string_literal: true

module Expressir
  module Express
    module Builders
      # Builds declaration nodes - dispatches to specific declaration type.
      class DeclarationBuilder
        def call(ast_data)
          %i[entity_decl function_decl procedure_decl subtype_constraint_decl
             type_decl].each do |key|
            if ast_data[key]
              return Builder.build({ key => ast_data[key] })
            end
          end
          nil
        end
      end
    end
  end
end
