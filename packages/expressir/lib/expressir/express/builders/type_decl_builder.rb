# frozen_string_literal: true

module Expressir
  module Express
    module Builders
      # Builds type_decl nodes.
      class TypeDeclBuilder
        def call(ast_data)
          id = Builder.build_optional(ast_data[:type_id])
          underlying_type = Builder.build_optional(ast_data[:underlying_type])
          where_rules = if ast_data[:where_clause]
                          Builder.build({ where_clause: ast_data[:where_clause] })
                        else
                          []
                        end

          Expressir::Model::Declarations::Type.new(
            id: id,
            underlying_type: underlying_type,
            where_rules: [where_rules].flatten,
          )
        end
      end
    end
  end
end
