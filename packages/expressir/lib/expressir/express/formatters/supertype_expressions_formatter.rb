module Expressir
  module Express
    module Formatters
      module SupertypeExpressionsFormatter
        def self.included(base)
          base.register_formatter Model::SupertypeExpressions::BinarySupertypeExpression,
                                  :format_supertype_expressions_binary_supertype_expression
          base.register_formatter Model::SupertypeExpressions::OneofSupertypeExpression,
                                  :format_supertype_expressions_oneof_supertype_expression
        end

        def format_supertype_expressions_binary_supertype_expression(node)
          supertype_precedence = self.class.const_get(:SUPERTYPE_OPERATOR_PRECEDENCE)
          op1_higher_precedence = node.operand1.is_a?(Model::SupertypeExpressions::BinarySupertypeExpression) &&
            (supertype_precedence[node.operand1.operator] > supertype_precedence[node.operator])
          op2_higher_precedence = node.operand2.is_a?(Model::SupertypeExpressions::BinarySupertypeExpression) &&
            (supertype_precedence[node.operand2.operator] > supertype_precedence[node.operator])

          [
            *if op1_higher_precedence
               "("
             end,
            format(node.operand1),
            *if op1_higher_precedence
               ")"
             end,
            " ",
            case node.operator
            when Model::SupertypeExpressions::BinarySupertypeExpression::AND then "AND"
            when Model::SupertypeExpressions::BinarySupertypeExpression::ANDOR then "ANDOR"
            end,
            " ",
            *if op2_higher_precedence
               "("
             end,
            format(node.operand2),
            *if op2_higher_precedence
               ")"
             end,
          ].join
        end

        def format_supertype_expressions_oneof_supertype_expression(node)
          [
            "ONEOF",
            "(",
            Array(node.operands).map { |x| format(x) }.join(", "),
            ")",
          ].join
        end
      end
    end
  end
end
