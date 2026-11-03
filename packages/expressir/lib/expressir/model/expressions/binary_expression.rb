module Expressir
  module Model
    module Expressions
      # Specified in ISO 10303-11:2004
      # - section 12.1 Arithmetic operators
      # - section 12.2 Relational operators
      # - section 12.3 Binary operators
      # - section 12.4 Logical operators
      # - section 12.5 String operators
      # - section 12.6 Aggregate operators
      # - section 12.10 Complex entity instance construction operator
      class BinaryExpression < ModelElement
        child_attributes :operand1, :operand2
        ADDITION = "ADDITION".freeze
        AND = "AND".freeze
        COMBINE = "COMBINE".freeze
        EQUAL = "EQUAL".freeze
        EXPONENTIATION = "EXPONENTIATION".freeze
        GREATER_THAN = "GREATER_THAN".freeze
        GREATER_THAN_OR_EQUAL = "GREATER_THAN_OR_EQUAL".freeze
        IN = "IN".freeze
        INSTANCE_EQUAL = "INSTANCE_EQUAL".freeze
        INSTANCE_NOT_EQUAL = "INSTANCE_NOT_EQUAL".freeze
        INTEGER_DIVISION = "INTEGER_DIVISION".freeze
        LESS_THAN = "LESS_THAN".freeze
        LESS_THAN_OR_EQUAL = "LESS_THAN_OR_EQUAL".freeze
        LIKE = "LIKE".freeze
        MODULO = "MODULO".freeze
        MULTIPLICATION = "MULTIPLICATION".freeze
        NOT_EQUAL = "NOT_EQUAL".freeze
        OR = "OR".freeze
        REAL_DIVISION = "REAL_DIVISION".freeze
        SUBTRACTION = "SUBTRACTION".freeze
        XOR = "XOR".freeze

        attribute :operator, :string,
                  values: %w[
                    ADDITION AND COMBINE EQUAL EXPONENTIATION
                    GREATER_THAN
                    GREATER_THAN_OR_EQUAL IN INSTANCE_EQUAL
                    INSTANCE_NOT_EQUAL
                    INTEGER_DIVISION LESS_THAN LESS_THAN_OR_EQUAL LIKE
                    MODULO MULTIPLICATION NOT_EQUAL OR REAL_DIVISION
                    SUBTRACTION XOR
                  ]
        attribute :operand1, ModelElement
        attribute :operand2, ModelElement
        attribute :_class, :string, default: -> { self.class.name }

        key_value do
          map "_class", to: :_class, render_default: true
          map "operator", to: :operator
          map "operand1", to: :operand1
          map "operand2", to: :operand2
        end
      end
    end
  end
end
