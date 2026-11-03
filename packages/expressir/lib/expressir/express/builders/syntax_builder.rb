# frozen_string_literal: true

module Expressir
  module Express
    module Builders
      # Builds syntax (top-level) nodes into ExpFile objects.
      # Each parsed EXPRESS file is represented as an ExpFile containing schemas.
      class SyntaxBuilder
        # Build ExpFile from AST data
        # @param ast_data [Hash] The parsed AST with syntax node
        # @return [Model::ExpFile] ExpFile containing the parsed schemas
        def call(ast_data)
          schema_decl_data = extract_schema_decls(ast_data)

          schemas = Builder.build_children(schema_decl_data)
          Expressir::Model::ExpFile.new(schemas: schemas.compact)
        end

        private

        # Extract schema declarations from AST data.
        def extract_schema_decls(ast_data)
          if ast_data.is_a?(Hash)
            ast_data[:schema_decl]
          end
        end
      end
    end
  end
end
