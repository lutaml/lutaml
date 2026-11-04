# frozen_string_literal: true

module Expressir
  module Express
    module Builders
      # Builds function declaration nodes.
      class FunctionDeclBuilder
        def call(ast_data)
          head = ast_data[:function_head]
          algorithm_head = ast_data[:algorithm_head]
          stmts = ast_data[:stmt]

          id = Builder.build_optional(head[:function_id]) if head
          parameters = build_parameters(head)
          return_type = Builder.build_optional(head[:parameter_type]) if head

          declarations = []
          if algorithm_head.is_a?(Hash)
            declarations = Builder.build_children(algorithm_head[:declaration])
          end

          types = declarations.grep(Expressir::Model::Declarations::Type)
          entities = declarations.grep(Expressir::Model::Declarations::Entity)
          subtype_constraints = declarations.grep(Expressir::Model::Declarations::SubtypeConstraint)
          functions = declarations.grep(Expressir::Model::Declarations::Function)
          procedures = declarations.grep(Expressir::Model::Declarations::Procedure)
          constants = if algorithm_head.is_a?(Hash) && algorithm_head[:constant_decl]
                        build_constant_decl(algorithm_head[:constant_decl])
                      else
                        []
                      end
          variables = if algorithm_head.is_a?(Hash) && algorithm_head[:local_decl]
                        build_local_decl(algorithm_head[:local_decl])
                      else
                        []
                      end
          statements = Builder.build_children(stmts)

          Expressir::Model::Declarations::Function.new(
            id: id,
            parameters: parameters,
            return_type: return_type,
            types: types,
            entities: entities,
            subtype_constraints: subtype_constraints,
            functions: functions,
            procedures: procedures,
            constants: constants,
            variables: variables,
            statements: statements.compact,
          )
        end

        private

        def build_parameters(head)
          # nil = no parameter parentheses in the source; [] = explicit
          # `f()` (the list is optional within the parens, syntax 253)
          group = head && head[:function_head_parameter_group]
          # the parslet-compatible transform carries a failed .maybe as []
          return nil if group.nil? || (group.respond_to?(:empty?) && group.empty?)

          params_data = group[:list_of_formal_parameter]
          return [] unless params_data

          params_data = head[:list_of_formal_parameter] if params_data.nil?
          if params_data.is_a?(Hash) && params_data[:formal_parameter]
            params_data = [params_data[:formal_parameter]]
          elsif params_data.is_a?(Array)
            params_data = params_data.filter_map do |p|
              p[:formal_parameter] if p.is_a?(Hash)
            end
          end

          parameters = []
          Builder.ensure_array(params_data).each do |param|
            result = Builder.build({ formal_parameter: param })
            parameters.concat(Builder.ensure_array(result)) if result
          end
          parameters
        end

        def build_constant_decl(data)
          Builder.build_children(data[:constant_body])
        end

        def build_local_decl(data)
          Builder.build_children(data[:local_variable])
        end
      end
    end
  end
end
