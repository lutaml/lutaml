module Expressir
  module Model
    module Expressions
      # Specified in ISO 10303-11:2004
      # - section 12.9 Aggregate initializer
      class AggregateInitializer < ModelElement
        child_attributes :items
        attribute :items, ModelElement, collection: true, initialize_empty: true
        attribute :_class, :string, default: -> { self.class.name }

        key_value do
          map "_class", to: :_class, render_default: true
          map "items", to: :items
        end
      end
    end
  end
end
