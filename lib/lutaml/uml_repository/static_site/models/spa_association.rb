# frozen_string_literal: true

module Lutaml
  module UmlRepository
    module StaticSite
      module Models
        class SpaAssociation < SpaBase
          attribute :id, :string
          attribute :xmi_id, :string
          attribute :name, :string
          attribute :type, :string
          attribute :definition, :string
          attribute :source, SpaAssociationEnd
          attribute :target, SpaAssociationEnd

          json do
            map "id", to: :id
            map "xmiId", to: :xmi_id
            map "name", to: :name
            map "type", to: :type
            map "definition", to: :definition
            map "source", to: :source
            map "target", to: :target
          end
        end
      end
    end
  end
end
