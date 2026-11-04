module Expressir
  module Model
    module Declarations
      # Specified in ISO 10303-11:2004
      # - section 11 Interface specification
      class InterfacedItem < ModelElement
        include HasId
        include HasRemarks

        attribute :id, :string
        attribute :remarks, :string, collection: true, initialize_empty: true
        attribute :remark_items, RemarkItem, collection: true, initialize_empty: true
        attribute :base_item, ModelElement
        attribute :_class, :string, default: -> { self.class.name }

        key_value do
          map "_class", to: :_class, render_default: true
          map "id", to: :id
          map "remarks", to: :remarks
          map "remark_items", to: :remark_items
          map "base_item", to: :base_item
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
