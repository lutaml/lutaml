# frozen_string_literal: true

module Expressir
  module Express
    module Builders
      # Builds statement nodes (assignment, if, case, repeat, etc.).
      class StatementBuilder
        include ::Expressir::Express::Builders::Helpers

        # stmt - choice dispatcher
        def build_stmt(ast_data)
          if ast_data[:assignment_stmt]
            Builder.build({ assignment_stmt: ast_data[:assignment_stmt] })
          elsif ast_data[:alias_stmt]
            Builder.build({ alias_stmt: ast_data[:alias_stmt] })
          elsif ast_data[:if_stmt]
            Builder.build({ if_stmt: ast_data[:if_stmt] })
          elsif ast_data[:case_stmt]
            Builder.build({ case_stmt: ast_data[:case_stmt] })
          elsif ast_data[:compound_stmt]
            Builder.build({ compound_stmt: ast_data[:compound_stmt] })
          elsif ast_data[:repeat_stmt]
            Builder.build({ repeat_stmt: ast_data[:repeat_stmt] })
          elsif ast_data[:return_stmt]
            Builder.build({ return_stmt: ast_data[:return_stmt] })
          elsif ast_data[:escape_stmt]
            Builder.build({ escape_stmt: ast_data[:escape_stmt] })
          elsif ast_data[:skip_stmt]
            Builder.build({ skip_stmt: ast_data[:skip_stmt] })
          elsif ast_data[:null_stmt]
            Builder.build({ null_stmt: ast_data[:null_stmt] })
          elsif ast_data[:procedure_call_stmt]
            Builder.build({ procedure_call_stmt: ast_data[:procedure_call_stmt] })
          end
        end

        def build_assignment_stmt(ast_data)
          ref = Builder.build_optional(ast_data[:general_ref])
          expression = if ast_data[:expression]
                         Builder.build({ expression: ast_data[:expression] })
                       end

          if ast_data[:qualifier]
            Builder.ensure_array(ast_data[:qualifier]).each do |qual|
              qual_result = Builder.build({ qualifier: qual })
              ref = apply_qualifier(ref, qual_result)
            end
          end

          Expressir::Model::Statements::Assignment.new(ref: ref,
                                                       expression: expression)
        end

        def build_alias_stmt(ast_data)
          var_id = Builder.build_optional(ast_data[:variable_id])
          expression = Builder.build_optional(ast_data[:general_ref])
          statements = Builder.build_children(ast_data[:stmt])

          if ast_data[:qualifier] && expression
            Builder.ensure_array(ast_data[:qualifier]).each do |qual|
              qual_result = Builder.build({ qualifier: qual })
              expression = apply_qualifier(expression, qual_result)
            end
          end

          Expressir::Model::Statements::Alias.new(
            id: var_id,
            expression: expression,
            statements: statements.compact,
          )
        end

        def build_if_stmt(ast_data)
          expression = Builder.build_optional(ast_data[:logical_expression])
          then_stmts = Builder.build_children(ast_data[:if_stmt_statements]&.dig(:stmt))
          else_stmts = Builder.build_children(ast_data[:if_stmt_else_statements]&.dig(:stmt))

          Expressir::Model::Statements::If.new(
            expression: expression,
            statements: then_stmts.compact,
            else_statements: else_stmts.compact,
          )
        end

        def build_case_stmt(ast_data)
          selector = Builder.build_optional(ast_data[:selector])
          actions = Builder.build_children(ast_data[:case_action])
          otherwise_stmt = if ast_data[:t_otherwise] && ast_data[:stmt].is_a?(Hash)
                             Builder.build({ stmt: ast_data[:stmt] })
                           end

          Expressir::Model::Statements::Case.new(
            expression: selector,
            actions: actions.compact,
            otherwise_statement: otherwise_stmt,
          )
        end

        def build_selector(ast_data)
          if ast_data[:expression]
            Builder.build({ expression: ast_data[:expression] })
          end
        end

        def build_case_action(ast_data)
          label_data = ast_data[:list_of_case_label]
          labels = if label_data.is_a?(Hash)
                     Builder.build_children(label_data[:case_label])
                   elsif label_data.is_a?(Array)
                     label_data.flat_map do |item|
                       Builder.build_children(item.is_a?(Hash) ? item[:case_label] : item)
                     end
                   else
                     []
                   end
          stmt = if ast_data[:stmt].is_a?(Hash)
                   Builder.build({ stmt: ast_data[:stmt] })
                 end

          Expressir::Model::Statements::CaseAction.new(
            labels: labels.compact,
            statement: stmt,
          )
        end

        def build_case_label(ast_data)
          if ast_data[:expression]
            Builder.build({ expression: ast_data[:expression] })
          end
        end

        def build_compound_stmt(ast_data)
          statements = Builder.build_children(ast_data[:stmt])
          Expressir::Model::Statements::Compound.new(statements: statements.compact)
        end

        def build_repeat_stmt(ast_data)
          control = ast_data[:repeat_control]
          statements = Builder.build_children(ast_data[:stmt])

          var_id = nil
          bound1 = nil
          bound2 = nil
          increment = nil

          increment_control = control[:increment_control] if control.is_a?(Hash)
          if increment_control.is_a?(Hash)
            var_id = Builder.build_optional(increment_control[:variable_id])
            bound1 = Builder.build_optional(increment_control[:bound1])
            bound2 = Builder.build_optional(increment_control[:bound2])
            increment = Builder.build_optional(increment_control[:increment])
          end

          while_ctrl = control.is_a?(Hash) ? control[:while_control] : nil
          until_ctrl = control.is_a?(Hash) ? control[:until_control] : nil

          while_expression = if while_ctrl.is_a?(Hash)
                               Builder.build_optional(while_ctrl[:logical_expression])
                             end
          until_expression = if until_ctrl.is_a?(Hash)
                               Builder.build_optional(until_ctrl[:logical_expression])
                             end

          Expressir::Model::Statements::Repeat.new(
            id: var_id,
            bound1: bound1,
            bound2: bound2,
            increment: increment,
            while_expression: while_expression,
            until_expression: until_expression,
            statements: statements.compact,
          )
        end

        def build_increment_control(_ast_data)
          nil
        end

        def build_increment(ast_data)
          Builder.build_optional(ast_data[:numeric_expression])
        end

        def build_while_control(ast_data)
          Builder.build_optional(ast_data[:logical_expression])
        end

        def build_until_control(ast_data)
          Builder.build_optional(ast_data[:logical_expression])
        end

        def build_return_stmt(ast_data)
          expression = if ast_data[:expression]
                         Builder.build({ expression: ast_data[:expression] })
                       end
          Expressir::Model::Statements::Return.new(expression: expression)
        end

        def build_escape_stmt(_ast_data)
          Expressir::Model::Statements::Escape.new
        end

        def build_skip_stmt(_ast_data)
          Expressir::Model::Statements::Skip.new
        end

        def build_null_stmt(_ast_data)
          Expressir::Model::Statements::Null.new
        end

        def build_procedure_call_stmt(ast_data)
          proc_ref = if ast_data[:procedure_ref]
                       Builder.build({ procedure_ref: ast_data[:procedure_ref] })
                     elsif ast_data[:built_in_procedure]
                       Builder.build({ built_in_procedure: ast_data[:built_in_procedure] })
                     end
          params = if ast_data[:actual_parameter_list]
                     Builder.build({ actual_parameter_list: ast_data[:actual_parameter_list] })
                   else
                     []
                   end

          Expressir::Model::Statements::ProcedureCall.new(
            procedure: proc_ref,
            parameters: Builder.ensure_array(params),
          )
        end

        def build_type_label(ast_data)
          if ast_data[:type_label_id]
            Builder.build({ type_label_id: ast_data[:type_label_id] })
          elsif ast_data[:type_label_ref]
            Builder.build({ type_label_ref: ast_data[:type_label_ref] })
          end
        end

        def build_type_label_ref(ast_data)
          id = extract_text(ast_data[:str] || ast_data[:type_label_id]&.dig(:str))
          Expressir::Model::References::SimpleReference.new(id: id)
        end
      end
    end
  end
end
