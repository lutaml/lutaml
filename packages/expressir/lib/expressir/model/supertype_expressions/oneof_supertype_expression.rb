module Expressir
  module Model
    module SupertypeExpressions
      # Specified in ISO 10303-11:2004
      # - section 9.2.5.2 ONEOF
      class OneofSupertypeExpression < ModelElement
        attribute :operands, ModelElement, collection: true, initialize_empty: true
        attribute :_class, :string, default: -> { self.class.name }

        key_value do
          map "_class", to: :_class, render_default: true
          map "operands", to: :operands
        end
      end
    end
  end
end
