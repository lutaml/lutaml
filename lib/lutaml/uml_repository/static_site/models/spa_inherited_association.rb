# frozen_string_literal: true

module Lutaml
  module UmlRepository
    module StaticSite
      module Models
        class SpaInheritedAssociation < SpaBase
          attribute :association_id, :string
          attribute :inherited_from, :string
          attribute :inherited_from_name, :string
          attribute :parent_order, :integer, default: 0
          attribute :local_role, :string

          json do
            map "associationId", to: :association_id
            map "inheritedFrom", to: :inherited_from
            map "inheritedFromName", to: :inherited_from_name
            map "parentOrder", to: :parent_order, render_default: true
            map "localRole", to: :local_role
          end
        end
      end
    end
  end
end
