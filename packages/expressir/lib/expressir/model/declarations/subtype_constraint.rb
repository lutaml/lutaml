module Expressir
  module Model
    module Declarations
      # Specified in ISO 10303-11:2004
      # - section 9.7 Subtype constraints
      class SubtypeConstraint < ModelElement
        include Identifier

        attribute :applies_to, ModelElement
        attribute :abstract, :boolean
        attribute :total_over, ModelElement, collection: true, initialize_empty: true
        attribute :supertype_expression, ModelElement
        attribute :_class, :string, default: -> { self.class.name }

        key_value do
          map "_class", to: :_class, render_default: true
          map "applies_to", to: :applies_to
          map "abstract", to: :abstract
          map "total_over", to: :total_over
          map "supertype_expression", to: :supertype_expression
        end

        # @return [Array<Declaration>]
        def children
          [
            *remark_items,
          ]
        end
      end
    end
  end
end
