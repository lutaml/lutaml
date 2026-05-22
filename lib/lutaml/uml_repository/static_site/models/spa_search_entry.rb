# frozen_string_literal: true

module Lutaml
  module UmlRepository
    module StaticSite
      module Models
        class SpaSearchEntry < SpaBase
          attribute :id, :string
          attribute :type, :string
          attribute :entity_type, :string
          attribute :entity_id, :string
          attribute :name, :string
          attribute :qualified_name, :string
          attribute :package, :string, default: ""
          attribute :content, :string
          attribute :boost, :float, default: 1.0

          json do
            map "id", to: :id
            map "type", to: :type
            map "entityType", to: :entity_type
            map "entityId", to: :entity_id
            map "name", to: :name
            map "qualifiedName", to: :qualified_name
            map "package", to: :package, render_nil: true,
                           render_default: true, render_empty: true
            map "content", to: :content
            map "boost", to: :boost, render_default: true
          end
        end
      end
    end
  end
end
