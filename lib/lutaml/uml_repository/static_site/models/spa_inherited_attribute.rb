# frozen_string_literal: true

module Lutaml
  module UmlRepository
    module StaticSite
      module Models
        class SpaInheritedAttribute < SpaBase
          attribute :attribute_id, :string
          attribute :attribute, SpaAttribute
          attribute :inherited_from, :string
          attribute :inherited_from_name, :string
          attribute :parent_order, :integer, default: 0

          json do
            map "attributeId", to: :attribute_id
            map "attribute", to: :attribute
            map "inheritedFrom", to: :inherited_from
            map "inheritedFromName", to: :inherited_from_name
            map "parentOrder", to: :parent_order, render_default: true
          end
        end
      end
    end
  end
end
