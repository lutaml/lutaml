module Expressir
  module Model
    module Expressions
      # Specified in ISO 10303-11:2004
      # - section 12.1 Arithmetic operators
      # - section 12.4.1 NOT operator
      class UnaryExpression < ModelElement
        child_attributes :operand
        MINUS = "MINUS".freeze
        NOT = "NOT".freeze
        PLUS = "PLUS".freeze

        attribute :operator, :string, values: %w[MINUS NOT PLUS]
        attribute :operand, ModelElement
        attribute :_class, :string, default: -> { self.class.name }

        key_value do
          map "_class", to: :_class, render_default: true
          map "operator", to: :operator
          map "operand", to: :operand
        end
      end
    end
  end
end
