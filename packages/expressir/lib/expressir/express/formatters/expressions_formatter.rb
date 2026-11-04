module Expressir
  module Express
    module Formatters
      module ExpressionsFormatter
        def self.included(base)
          base.register_formatter Model::Expressions::AggregateInitializer,
                                  :format_expressions_aggregate_initializer
          base.register_formatter Model::Expressions::AggregateInitializerItem,
                                  :format_expressions_aggregate_initializer_item
          base.register_formatter Model::Expressions::BinaryExpression,
                                  :format_expressions_binary_expression
          base.register_formatter Model::Expressions::EntityConstructor,
                                  :format_expressions_entity_constructor
          base.register_formatter Model::Expressions::FunctionCall,
                                  :format_expressions_function_call
          base.register_formatter Model::Expressions::Interval,
                                  :format_expressions_interval
          base.register_formatter Model::Expressions::QueryExpression,
                                  :format_expressions_query_expression
          base.register_formatter Model::Expressions::UnaryExpression,
                                  :format_expressions_unary_expression
        end

        def format_expressions_aggregate_initializer(node)
          [
            "[",
            Array(node.items).map { |x| format(x) }.join(", "),
            "]",
          ].join
        end

        def format_expressions_aggregate_initializer_item(node)
          [
            format(node.expression),
            ":",
            format(node.repetition),
          ].join
        end

        def format_expressions_binary_expression(node)
          operator_precedence = self.class.const_get(:OPERATOR_PRECEDENCE)
          op1_bin_exp = node.operand1.is_a?(Model::Expressions::BinaryExpression) &&
            (operator_precedence[node.operand1.operator] >= operator_precedence[node.operator])
          op2_bin_exp = node.operand2.is_a?(Model::Expressions::BinaryExpression) &&
            (operator_precedence[node.operand2.operator] >= operator_precedence[node.operator])

          [
            *if op1_bin_exp
               "("
             end,
            format(node.operand1),
            *if op1_bin_exp
               ")"
             end,
            " ",
            case node.operator
            when Model::Expressions::BinaryExpression::ADDITION then "+"
            when Model::Expressions::BinaryExpression::AND then "AND"
            when Model::Expressions::BinaryExpression::COMBINE then "||"
            when Model::Expressions::BinaryExpression::EQUAL then "="
            when Model::Expressions::BinaryExpression::EXPONENTIATION then "**"
            when Model::Expressions::BinaryExpression::GREATER_THAN then ">"
            when Model::Expressions::BinaryExpression::GREATER_THAN_OR_EQUAL then ">="
            when Model::Expressions::BinaryExpression::IN then "IN"
            when Model::Expressions::BinaryExpression::INSTANCE_EQUAL then ":=:"
            when Model::Expressions::BinaryExpression::INSTANCE_NOT_EQUAL then ":<>:"
            when Model::Expressions::BinaryExpression::INTEGER_DIVISION then "DIV"
            when Model::Expressions::BinaryExpression::LESS_THAN then "<"
            when Model::Expressions::BinaryExpression::LESS_THAN_OR_EQUAL then "<="
            when Model::Expressions::BinaryExpression::LIKE then "LIKE"
            when Model::Expressions::BinaryExpression::MODULO then "MOD"
            when Model::Expressions::BinaryExpression::MULTIPLICATION then "*"
            when Model::Expressions::BinaryExpression::NOT_EQUAL then "<>"
            when Model::Expressions::BinaryExpression::OR then "OR"
            when Model::Expressions::BinaryExpression::REAL_DIVISION then "/"
            when Model::Expressions::BinaryExpression::SUBTRACTION then "-"
            when Model::Expressions::BinaryExpression::XOR then "XOR"
            end,
            " ",
            *if op2_bin_exp
               "("
             end,
            format(node.operand2),
            *if op2_bin_exp
               ")"
             end,
          ].join
        end

        def format_expressions_entity_constructor(node)
          [
            format(node.entity),
            "(",
            Array(node.parameters).map { |x| format(x) }.join(", "),
            ")",
          ].join
        end

        def format_expressions_function_call(node)
          params = if node.parameters.nil?
                     []
                   else
                     [
                       "(",
                       node.parameters.map { |x| format(x) }.join(", "),
                       ")",
                     ]
                   end

          [format(node.function), params].join
        end

        def format_expressions_interval(node)
          [
            "{",
            format(node.low),
            " ",
            case node.operator1
            when Model::Expressions::Interval::LESS_THAN then "<"
            when Model::Expressions::Interval::LESS_THAN_OR_EQUAL then "<="
            end,
            " ",
            format(node.item),
            " ",
            case node.operator2
            when Model::Expressions::Interval::LESS_THAN then "<"
            when Model::Expressions::Interval::LESS_THAN_OR_EQUAL then "<="
            end,
            " ",
            format(node.high),
            "}",
          ].join
        end

        def format_expressions_query_expression(node)
          [
            "QUERY",
            "(",
            node.id,
            " ",
            "<*",
            " ",
            format(node.aggregate_source),
            " ",
            "|",
            " ",
            format(node.expression),
            *format_remarks(node).instance_eval do |x|
              x&.length&.positive? ? ["\n", *x, "\n"] : x
            end,
            ")",
          ].join
        end

        def format_expressions_unary_expression(node)
          needs_parens = node.operand.is_a?(Model::Expressions::BinaryExpression) ||
            node.operand.is_a?(Model::Expressions::Interval) ||
            # Nested unary must stay parenthesized: "- -x" is not a
            # simple factor, and "--x" opens a comment.
            node.operand.is_a?(Model::Expressions::UnaryExpression)

          [
            case node.operator
            when Model::Expressions::UnaryExpression::MINUS then "-"
            when Model::Expressions::UnaryExpression::NOT then "NOT"
            when Model::Expressions::UnaryExpression::PLUS then "+"
            end,
            if node.operator == Model::Expressions::UnaryExpression::NOT
              " "
            end,
            *if needs_parens
               "("
             end,
            format(node.operand),
            *if needs_parens
               ")"
             end,
          ].join
        end
      end
    end
  end
end
