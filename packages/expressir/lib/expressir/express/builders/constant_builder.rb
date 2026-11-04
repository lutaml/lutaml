# frozen_string_literal: true

module Expressir
  module Express
    module Builders
      # Builds constant and local variable nodes.
      class ConstantBuilder
        def build_constant_decl(ast_data)
          Builder.build_children(ast_data[:constant_body])
        end

        def build_constant_body(ast_data)
          id = Builder.build_optional(ast_data[:constant_id])
          type = Builder.build_optional(ast_data[:instantiable_type])
          expression = if ast_data[:expression]
                         Builder.build({ expression: ast_data[:expression] })
                       end

          Expressir::Model::Declarations::Constant.new(id: id, type: type,
                                                       expression: expression)
        end

        def build_local_decl(ast_data)
          Builder.build_children(ast_data[:local_variable])
        end

        def build_local_variable(ast_data)
          var_id_data = ast_data[:list_of_variable_id] || ast_data

          ids_data = if var_id_data.is_a?(Hash) && var_id_data[:variable_id]
                       var_id_data[:variable_id]
                     else
                       var_id_data
                     end

          ids = if ids_data.is_a?(Hash)
                  [Builder.build({ variable_id: ids_data })]
                elsif ids_data.is_a?(Array)
                  ids_data.filter_map do |elem|
                    actual_id = elem[:variable_id] || elem
                    Builder.build({ variable_id: actual_id })
                  end
                else
                  []
                end

          type = Builder.build_optional(ast_data[:parameter_type])
          expression = if ast_data[:expression]
                         Builder.build({ expression: ast_data[:expression] })
                       end

          ids.flatten.compact.map do |id|
            Expressir::Model::Declarations::Variable.new(id: id, type: type,
                                                         expression: expression)
          end
        end

        def build_formal_parameter(ast_data)
          param_id_data = ast_data[:list_of_parameter_id] || ast_data

          ids_data = if param_id_data.is_a?(Hash) && param_id_data[:parameter_id]
                       param_id_data[:parameter_id]
                     else
                       param_id_data
                     end

          ids = if ids_data.is_a?(Hash)
                  [Builder.build({ parameter_id: ids_data })]
                elsif ids_data.is_a?(Array)
                  ids_data.filter_map do |elem|
                    actual_id = elem[:parameter_id] || elem
                    Builder.build({ parameter_id: actual_id })
                  end
                else
                  []
                end

          type = Builder.build_optional(ast_data[:parameter_type])
          ids.flatten.compact.map { |id| Expressir::Model::Declarations::Parameter.new(id: id, type: type) }
        end

        def build_procedure_head_parameter(ast_data)
          formal_param_data = ast_data[:formal_parameter]
          params = if formal_param_data.is_a?(Hash)
                     result = Builder.build({ formal_parameter: formal_param_data })
                     Builder.ensure_array(result)
                   elsif formal_param_data.is_a?(Array)
                     formal_param_data.flat_map do |fp|
                       Builder.build({ formal_parameter: fp })
                     end.compact
                   else
                     []
                   end
          is_var = !ast_data[:t_var].nil?

          if is_var
            params.map do |p|
              Expressir::Model::Declarations::Parameter.new(id: p.id,
                                                            var: true, type: p.type)
            end
          else
            params
          end
        end
      end
    end
  end
end
