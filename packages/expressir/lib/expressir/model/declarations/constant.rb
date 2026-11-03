module Expressir
  module Model
    module Declarations
      # Specified in ISO 10303-11:2004
      # - section 9.4 Constant
      class Constant < ModelElement
        include Identifier

        attribute :type, ModelElement
        attribute :expression, ModelElement
        attribute :_class, :string, default: -> { self.class.name }

        key_value do
          map "_class", to: :_class, render_default: true
          map "type", to: :type
          map "expression", to: :expression
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
