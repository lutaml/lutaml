module Expressir
  module Model
    module Statements
      # Specified in ISO 10303-11:2004
      # - section 13.2 Alias statement
      class Alias < ModelElement
        include Statement
        include Identifier

        collection_attributes :statements
        attribute :expression, ModelElement
        attribute :statements, ModelElement, collection: true, initialize_empty: true
        attribute :_class, :string, default: -> { self.class.name }

        key_value do
          map "_class", to: :_class, render_default: true
          map "expression", to: :expression
          map "statements", to: :statements
        end

        # @return [Array<Declaration>]
        def children
          [
            self,
            *remark_items,
          ]
        end
      end
    end
  end
end
