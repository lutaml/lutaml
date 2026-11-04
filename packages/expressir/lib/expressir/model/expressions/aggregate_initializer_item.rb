module Expressir
  module Model
    module Expressions
      # Specified in ISO 10303-11:2004
      # - section 12.9 Aggregate initializer
      class AggregateInitializerItem < ModelElement
        child_attributes :expression, :repetition
        attribute :expression, ModelElement
        attribute :repetition, ModelElement
        attribute :_class, :string, default: -> { self.class.name }

        key_value do
          map "_class", to: :_class, render_default: true
          map "expression", to: :expression
          map "repetition", to: :repetition
        end
      end
    end
  end
end
