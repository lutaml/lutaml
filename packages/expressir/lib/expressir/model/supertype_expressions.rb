# frozen_string_literal: true

module Expressir
  module Model
    module SupertypeExpressions
      autoload :BinarySupertypeExpression,
               "#{__dir__}/supertype_expressions/binary_supertype_expression"
      autoload :OneofSupertypeExpression,
               "#{__dir__}/supertype_expressions/oneof_supertype_expression"
    end
  end
end
