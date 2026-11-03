# frozen_string_literal: true

module Expressir
  module Express
    module Builders
      # Builds expression nodes (binary, unary, query, interval, etc.).
      class ExpressionBuilder
        include ::Expressir::Express::Builders::Helpers

        # Expression
        def build_expression(ast_data)
          left = if ast_data[:simple_expression]
                   Builder.build_node(:simple_expression, ast_data[:simple_expression])
                 elsif ast_data[:logical_expression]
                   Builder.build_node(:simple_expression, ast_data[:logical_expression][:simple_expression])
                 end

          if ast_data[:rel_op_extended] && ast_data[:rhs]
            op = build_rel_op_extended(ast_data[:rel_op_extended])
            right = Builder.build(ast_data[:rhs])
            Expressir::Model::Expressions::BinaryExpression.new(
              operator: op,
              operand1: left,
              operand2: right,
            )
          else
            left
          end
        end

        def build_logical_expression(ast_data)
          Builder.build_node(:simple_expression, ast_data[:simple_expression])
        end

        def build_numeric_expression(ast_data)
          Builder.build_node(:simple_expression, ast_data[:simple_expression])
        end

        # Simple expression (addition/subtraction chain)
        def build_simple_expression(ast_data)
          return nil unless ast_data[:term]

          term = Builder.build_node(:term, ast_data[:term])
          rhs = ast_data[:rhs]

          return term if rhs.nil? || (rhs.is_a?(Array) && rhs.empty?)

          rhs_array = rhs.is_a?(Array) ? rhs : [rhs]

          operands = [term]
          operators = []

          rhs_array.each do |r|
            # Handle Hash.each yielding [key, value] arrays
            r = r.last if r.is_a?(Array) && r.length == 2

            next unless r.is_a?(Hash)

            item = r[:item] || r
            op_data = item[:operator]
            operators << extract_operator(op_data[:add_like_op]) if op_data
            if item[:term]
              operands << Builder.build_node(:term, item[:term])
            end
          end

          build_binary_expression(operands, operators)
        end

        # Term (multiplication/division chain)
        def build_term(ast_data)
          return nil unless ast_data[:factor]

          factor = Builder.build_node(:factor, ast_data[:factor])
          rhs = ast_data[:rhs]

          return factor if rhs.nil? || (rhs.is_a?(Array) && rhs.empty?)

          rhs_array = rhs.is_a?(Array) ? rhs : [rhs]

          operands = [factor]
          operators = []

          rhs_array.each do |r|
            # Handle Hash.each yielding [key, value] arrays
            r = r.last if r.is_a?(Array) && r.length == 2

            next unless r.is_a?(Hash)

            item = r[:item] || r
            op_data = item[:multiplication_like_op] || item[:mul_like_op]
            operators << extract_operator(op_data) if op_data
            operands << Builder.build_node(:factor, item[:factor]) if item[:factor]
          end

          build_binary_expression(operands, operators)
        end

        def build_factor(ast_data)
          return nil unless ast_data[:simple_factor]

          base = Builder.build_node(:simple_factor, ast_data[:simple_factor])
          rhs = ast_data[:rhs]
          return base unless rhs

          Model::Expressions::BinaryExpression.new(
            operator: Model::Expressions::BinaryExpression::EXPONENTIATION,
            operand1: base,
            operand2: Builder.build_node(:simple_factor, rhs[:simple_factor]),
          )
        end

        def build_simple_factor(ast_data)
          return nil unless ast_data

          if ast_data[:primary]
            Builder.build_node(:primary, ast_data[:primary])
          elsif ast_data[:simple_factor_expression]
            Builder.build_node(:simple_factor_expression,
                               ast_data[:simple_factor_expression])
          elsif ast_data[:simple_factor_unary_expression]
            Builder.build_node(:simple_factor_unary_expression,
                               ast_data[:simple_factor_unary_expression])
          elsif ast_data[:constant_factor]
            Builder.build_node(:constant_factor, ast_data[:constant_factor])
          elsif ast_data[:expression]
            Builder.build_node(:expression, ast_data[:expression])
          elsif ast_data[:aggregate_initializer]
            Builder.build_node(:aggregate_initializer,
                               ast_data[:aggregate_initializer])
          elsif ast_data[:query_expression]
            Builder.build_node(:query_expression, ast_data[:query_expression])
          elsif ast_data[:entity_constructor]
            Builder.build_node(:entity_constructor,
                               ast_data[:entity_constructor])
          elsif ast_data[:interval]
            Builder.build_node(:interval, ast_data[:interval])
          elsif ast_data[:string_literal]
            Builder.build_node(:string_literal, ast_data[:string_literal])
          elsif ast_data[:enumeration_reference]
            Builder.build_node(:enumeration_reference,
                               ast_data[:enumeration_reference])
          end
        end

        def build_simple_factor_expression(ast_data)
          if ast_data[:primary]
            Builder.build_node(:primary, ast_data[:primary])
          elsif ast_data[:expression]
            Builder.build_node(:expression, ast_data[:expression])
          end
        end

        def build_simple_factor_unary_expression(ast_data)
          op = extract_unary_op(ast_data[:unary_op])
          operand = if ast_data[:simple_factor]
                      Builder.build_node(:simple_factor, ast_data[:simple_factor])
                    elsif ast_data[:simple_factor_expression]
                      Builder.build_node(:simple_factor_expression,
                                         ast_data[:simple_factor_expression])
                    elsif ast_data[:primary]
                      Builder.build_node(:primary, ast_data[:primary])
                    end

          if op
            Expressir::Model::Expressions::UnaryExpression.new(
              operator: op,
              operand: operand,
            )
          else
            operand
          end
        end

        def build_constant_factor(ast_data)
          if ast_data[:built_in_constant]
            Builder.build_node(:built_in_constant, ast_data[:built_in_constant])
          elsif ast_data[:constant_ref]
            Builder.build_node(:constant_ref, ast_data[:constant_ref])
          end
        end

        def build_primary(ast_data)
          if ast_data[:literal]
            Builder.build_node(:literal, ast_data[:literal])
          elsif ast_data[:qualifiable_factor]
            build_qualifiable_factor(ast_data[:qualifiable_factor],
                                     ast_data[:qualifier])
          elsif ast_data[:population]
            build_population(ast_data[:population], ast_data[:qualifier])
          elsif ast_data[:expression]
            Builder.build_node(:expression, ast_data[:expression])
          end
        end

        def build_qualifiable_factor(ast_data, qualifiers = nil)
          ref = nil
          if ast_data[:constant_factor]
            ref = Builder.build_node(:constant_factor,
                                     ast_data[:constant_factor])
          elsif ast_data[:function_call]
            ref = Builder.build_node(:function_call, ast_data[:function_call])
          else
            %i[constant_ref function_ref general_ref parameter_ref type_label_ref
               variable_ref attribute_ref entity_ref type_ref enumeration_ref].each do |key|
              if ast_data[key]
                ref = Builder.build_node(key, ast_data[key])
                break
              end
            end
          end

          return ref unless qualifiers

          Builder.ensure_array(qualifiers).each do |qual|
            qual_result = Builder.build_node(:qualifier, qual)
            ref = apply_qualifier(ref, qual_result)
          end
          ref
        end

        def build_population(ast_data, qualifiers = nil)
          ref = Builder.build_node(:entity_ref, ast_data[:entity_ref])
          return ref unless qualifiers

          Builder.ensure_array(qualifiers).each do |qual|
            qual_result = Builder.build_node(:qualifier, qual)
            ref = apply_qualifier(ref, qual_result)
          end
          ref
        end

        def build_qualifier(ast_data)
          data = ast_data[:qualifier] || ast_data
          if data[:attribute_qualifier]
            Builder.build_node(:attribute_qualifier,
                               data[:attribute_qualifier])
          elsif data[:group_qualifier]
            Builder.build_node(:group_qualifier, data[:group_qualifier])
          elsif data[:index_qualifier]
            Builder.build_node(:index_qualifier, data[:index_qualifier])
          end
        end

        def build_rel_op_extended(ast_data)
          extract_rel_op(ast_data[:rel_op] || ast_data)
        end

        def build_binary_expression(operands, operators)
          return operands.first if operands.length == 1
          return nil if operands.empty? || operators.empty?

          result = Expressir::Model::Expressions::BinaryExpression.new(
            operator: operators.first,
            operand1: operands.first,
            operand2: operands[1],
          )

          (2...operands.length).each do |i|
            result = Expressir::Model::Expressions::BinaryExpression.new(
              operator: operators[i - 1],
              operand1: result,
              operand2: operands[i],
            )
          end
          result
        end

        # Function call
        def build_function_call(ast_data)
          func_ref = if ast_data[:built_in_function]
                       Builder.build_node(:built_in_function,
                                          ast_data[:built_in_function])
                     elsif ast_data[:function_ref]
                       Builder.build_node(:function_ref,
                                          ast_data[:function_ref])
                     end

          # nil parameters = no paren list in the source (a plain
          # reference); [] = explicit `f()` — the formatter writes
          # the distinction back (#556).
          params = if ast_data[:actual_parameter_list]
                     Builder.build_node(:actual_parameter_list,
                                        ast_data[:actual_parameter_list])
                   end

          if params.nil?
            func_ref
          else
            Expressir::Model::Expressions::FunctionCall.new(
              function: func_ref,
              parameters: params,
            )
          end
        end

        def build_actual_parameter_list(ast_data)
          list_data = ast_data[:list_of_parameter] || ast_data[:parameter]

          case list_data
          when Hash
            Builder.build_children(list_data[:parameter])
          when Array
            list_data.flat_map do |item|
              if item.is_a?(Hash) && item[:parameter]
                Builder.build_children(item[:parameter])
              else
                []
              end
            end
          else
            []
          end
        end

        def build_parameter(ast_data)
          if ast_data[:expression]
            Builder.build({ expression: ast_data[:expression] })
          end
        end

        # Entity constructor
        def build_entity_constructor(ast_data)
          entity_ref = Builder.build_optional(ast_data[:entity_ref])
          params = if ast_data[:actual_parameter_list]
                     Builder.build_node(:actual_parameter_list,
                                        ast_data[:actual_parameter_list])
                   else
                     []
                   end

          Expressir::Model::Expressions::FunctionCall.new(
            function: entity_ref,
            parameters: params,
          )
        end

        # Query expression
        def build_query_expression(ast_data)
          var_id = Builder.build_optional(ast_data[:variable_id])
          aggregate_source = Builder.build_optional(ast_data[:aggregate_source])
          logical_expr = Builder.build_optional(ast_data[:logical_expression])

          Expressir::Model::Expressions::QueryExpression.new(
            id: var_id,
            aggregate_source: aggregate_source,
            expression: logical_expr,
          )
        end

        def build_aggregate_source(ast_data)
          Builder.build_optional(ast_data[:simple_expression])
        end

        # Aggregate initializer
        def build_aggregate_initializer(ast_data)
          list_data = ast_data[:list_of_element] || ast_data
          elements = if list_data.is_a?(Array)
                       list_data
                     else
                       list_data[:element]
                     end

          items = elements ? Builder.build_children(elements) : []
          Expressir::Model::Expressions::AggregateInitializer.new(items: items.compact)
        end

        def build_element(ast_data)
          expression = if ast_data[:expression]
                         Builder.build({ expression: ast_data[:expression] })
                       end
          repetition = Builder.build_optional(ast_data[:repetition])

          if repetition
            Expressir::Model::Expressions::AggregateInitializerItem.new(
              expression: expression,
              repetition: repetition,
            )
          else
            expression
          end
        end

        def build_repetition(ast_data)
          Builder.build_optional(ast_data[:numeric_expression])
        end

        # Interval
        def build_interval(ast_data)
          low = Builder.build_optional(ast_data[:interval_low])
          item = Builder.build_optional(ast_data[:interval_item])
          high = Builder.build_optional(ast_data[:interval_high])

          op1 = extract_interval_op(ast_data[:interval_op])
          op2_data = ast_data[:interval_op2]
          op2 = if op2_data.is_a?(Hash) && op2_data[:interval_op]
                  extract_interval_op(op2_data[:interval_op])
                else
                  extract_interval_op(op2_data)
                end

          Expressir::Model::Expressions::Interval.new(
            low: low,
            operator1: op1,
            item: item,
            operator2: op2,
            high: high,
          )
        end

        def build_interval_low(ast_data)
          Builder.build_optional(ast_data[:simple_expression])
        end

        def build_interval_high(ast_data)
          Builder.build_optional(ast_data[:simple_expression])
        end

        def build_interval_item(ast_data)
          Builder.build_optional(ast_data[:simple_expression])
        end
      end
    end
  end
end
