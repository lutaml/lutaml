module Expressir
  module Model
    module Expressions
      # Specified in ISO 10303-11:2004
      # - section 12.6.7 Query expression
      class QueryExpression < ModelElement
        include Identifier

        child_attributes :expression, :aggregate_source

        attribute :aggregate_source, ModelElement
        attribute :expression, ModelElement
        attribute :_class, :string, default: -> { self.class.name }

        key_value do
          map "_class", to: :_class, render_default: true
          map "aggregate_source", to: :aggregate_source
          map "expression", to: :expression
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
