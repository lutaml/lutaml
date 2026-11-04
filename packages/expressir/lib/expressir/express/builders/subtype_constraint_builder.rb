# frozen_string_literal: true

module Expressir
  module Express
    module Builders
      # Builds subtype constraint and supertype expression nodes.
      class SubtypeConstraintBuilder
        def build_subtype_constraint_decl(ast_data)
          head = ast_data[:subtype_constraint_head]
          body = ast_data[:subtype_constraint_body]

          id = Builder.build_optional(head[:subtype_constraint_id]) if head
          applies_to = if head && head[:entity_ref]
                         Builder.build({ entity_ref: head[:entity_ref] })
                       end

          abstract = false
          total_over = []
          supertype_expression = nil

          if body.is_a?(Hash)
            abstract = !body[:abstract_supertype].nil?
            if body[:total_over].is_a?(Hash)
              refs = body[:total_over][:list_of_entity_ref] ||
                body[:total_over][:entity_ref]
              total_over = Builder.build_children(Builder.ensure_array(refs))
            end
            # Wrap supertype_expression in its node type so Builder.build dispatches correctly
            supertype_expression = if body[:supertype_expression]
                                     Builder.build({ supertype_expression: body[:supertype_expression] })
                                   end
          end

          Expressir::Model::Declarations::SubtypeConstraint.new(
            id: id,
            applies_to: applies_to,
            abstract: abstract,
            total_over: total_over,
            supertype_expression: supertype_expression,
          )
        end

        def build_total_over(ast_data)
          Builder.build_children(ast_data[:entity_ref])
        end

        def build_supertype_expression(ast_data)
          return nil unless ast_data

          base_factor = ast_data[:supertype_factor]
          return nil unless base_factor

          # Handle both formats:
          # - With item wrapper: {item: {operator: {...}, supertype_factor: {...}}}
          # - Without item wrapper: {operator: {...}, supertype_factor: {...}}
          factors = [base_factor] + Builder.ensure_array(ast_data[:rhs]).filter_map do |r|
            r[:item]&.dig(:supertype_factor) || r[:supertype_factor]
          end
          operators = Builder.ensure_array(ast_data[:rhs]).map do |r|
            (r[:item]&.dig(:operator) || r[:operator])&.values&.first
          end

          if factors.length == 1
            Builder.build({ supertype_factor: factors.first })
          elsif factors.length >= 2
            operands = factors.map do |f|
              Builder.build({ supertype_factor: f })
            end
            build_binary_supertype_expression(operands, operators.map do
              :ANDOR
            end)
          end
        end

        def build_supertype_factor(ast_data)
          return nil unless ast_data

          base_term = ast_data[:supertype_term]
          return nil unless base_term

          # Handle both formats:
          # - With item wrapper: {item: {operator: {...}, supertype_term: {...}}}
          # - Without item wrapper: {operator: {...}, supertype_term: {...}}
          terms = [base_term] + Builder.ensure_array(ast_data[:rhs]).filter_map do |r|
            r[:item]&.dig(:supertype_term) || r[:supertype_term]
          end
          operators = Builder.ensure_array(ast_data[:rhs]).map do |r|
            (r[:item]&.dig(:operator) || r[:operator])&.values&.first
          end

          if terms.length == 1
            Builder.build({ supertype_term: terms.first })
          elsif terms.length >= 2
            operands = terms.map { |t| Builder.build({ supertype_term: t }) }
            build_binary_supertype_expression(operands, operators.map { :AND })
          end
        end

        def build_binary_supertype_expression(operands, operators)
          result = Expressir::Model::SupertypeExpressions::BinarySupertypeExpression.new(
            operator: operators.first,
            operand1: operands.first,
            operand2: operands[1],
          )
          (2...operands.length).each do |i|
            result = Expressir::Model::SupertypeExpressions::BinarySupertypeExpression.new(
              operator: operators[i - 1],
              operand1: result,
              operand2: operands[i],
            )
          end
          result
        end

        def build_supertype_term(ast_data)
          return nil unless ast_data.is_a?(Hash)

          if ast_data[:entity_ref]
            Builder.build({ entity_ref: ast_data[:entity_ref] })
          elsif ast_data[:one_of]
            Builder.build({ one_of: ast_data[:one_of] })
          elsif ast_data[:supertype_expression]
            Builder.build({ supertype_expression: ast_data[:supertype_expression] })
          end
        end

        def build_one_of(ast_data)
          list_data = ast_data[:list_of_supertype_expression]
          operands = if list_data.is_a?(Array)
                       list_data.filter_map do |item|
                         next unless item.is_a?(Hash)

                         expr_data = item[:supertype_expression]
                         Builder.build({ supertype_expression: expr_data }) if expr_data
                       end
                     elsif list_data.is_a?(Hash)
                       expr_data = list_data[:supertype_expression]
                       [Builder.build({ supertype_expression: expr_data })] if expr_data
                     else
                       []
                     end
          Expressir::Model::SupertypeExpressions::OneofSupertypeExpression.new(operands: operands.compact)
        end

        def build_supertype_rule(ast_data)
          subtype_constraint = ast_data[:subtype_constraint]
          if subtype_constraint.is_a?(Hash)
            Builder.build({ subtype_constraint: subtype_constraint })
          end
        end

        def build_subtype_constraint(ast_data)
          expr_data = ast_data[:supertype_expression]
          if expr_data.is_a?(Hash)
            Builder.build({ supertype_expression: expr_data })
          end
        end

        def build_subtype_declaration(ast_data)
          refs = ast_data[:entity_ref] || ast_data[:list_of_entity_ref]&.dig(:entity_ref)
          Builder.build_children(Builder.ensure_array(refs))
        end
      end
    end
  end
end
