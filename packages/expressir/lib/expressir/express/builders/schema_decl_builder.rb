# frozen_string_literal: true

module Expressir
  module Express
    module Builders
      # Builds schema_decl nodes into Schema objects.
      class SchemaDeclBuilder
        def call(ast_data)
          id = Builder.build_optional(ast_data[:schema_id])
          version = if ast_data[:schema_version_id]
                      Builder.build({ schema_version_id: ast_data[:schema_version_id] })
                    end

          interfaces = []
          constants = []
          declarations = []

          if ast_data[:schema_body]
            interfaces = Builder.build_children(ast_data[:schema_body][:interface_specification])
            constants = build_constants(ast_data[:schema_body][:constant_decl])
            body_decls = ast_data[:schema_body][:schema_body_declaration]
            declarations = Builder.build_children(body_decls) if body_decls
          end

          types = declarations.grep(Expressir::Model::Declarations::Type)
          entities = declarations.grep(Expressir::Model::Declarations::Entity)
          subtype_constraints = declarations.grep(Expressir::Model::Declarations::SubtypeConstraint)
          functions = declarations.grep(Expressir::Model::Declarations::Function)
          rules = declarations.grep(Expressir::Model::Declarations::Rule)
          procedures = declarations.grep(Expressir::Model::Declarations::Procedure)

          Expressir::Model::Declarations::Schema.new(
            id: id,
            version: version,
            interfaces: interfaces.compact,
            constants: [constants].flatten,
            types: types,
            entities: entities,
            subtype_constraints: subtype_constraints,
            functions: functions,
            rules: rules,
            procedures: procedures,
          )
        end

        private

        def build_constants(data)
          return [] unless data

          Builder.build_children(data[:constant_body])
        end
      end
    end
  end
end
