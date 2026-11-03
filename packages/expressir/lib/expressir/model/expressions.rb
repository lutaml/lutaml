# frozen_string_literal: true

module Expressir
  module Model
    module Expressions
      autoload :AggregateInitializer,
               "#{__dir__}/expressions/aggregate_initializer"
      autoload :AggregateInitializerItem,
               "#{__dir__}/expressions/aggregate_initializer_item"
      autoload :BinaryExpression, "#{__dir__}/expressions/binary_expression"
      autoload :EntityConstructor, "#{__dir__}/expressions/entity_constructor"
      autoload :FunctionCall, "#{__dir__}/expressions/function_call"
      autoload :Interval, "#{__dir__}/expressions/interval"
      autoload :QueryExpression, "#{__dir__}/expressions/query_expression"
      autoload :UnaryExpression, "#{__dir__}/expressions/unary_expression"
    end
  end
end
