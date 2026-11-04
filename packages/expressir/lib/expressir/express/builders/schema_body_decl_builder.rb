# frozen_string_literal: true

module Expressir
  module Express
    module Builders
      # Builds schema_body_declaration nodes - dispatches to declaration or rule.
      class SchemaBodyDeclBuilder
        def call(ast_data)
          if ast_data[:declaration]
            Builder.build({ declaration: ast_data[:declaration] })
          elsif ast_data[:rule_decl]
            Builder.build({ rule_decl: ast_data[:rule_decl] })
          end
        end
      end
    end
  end
end
