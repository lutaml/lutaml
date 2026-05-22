# frozen_string_literal: true

module Lutaml
  module UmlRepository
    module StaticSite
      module Models
        class SpaAttribute < SpaBase
          attribute :id, :string
          attribute :name, :string
          attribute :type, :string
          attribute :visibility, :string
          attribute :owner, :string
          attribute :owner_name, :string
          attribute :cardinality, SpaCardinality
          attribute :definition, :string
          attribute :stereotypes, :string, collection: true,
                                           initialize_empty: true
          attribute :is_static, :boolean, default: false
          attribute :is_read_only, :boolean, default: false
          attribute :default_value, :string

          json do
            map "id", to: :id
            map "name", to: :name
            map "type", to: :type
            map "visibility", to: :visibility
            map "owner", to: :owner
            map "ownerName", to: :owner_name
            map "cardinality", to: :cardinality
            map "definition", to: :definition
            map "stereotypes", to: :stereotypes, render_empty: true
            map "isStatic", to: :is_static, render_default: true
            map "isReadOnly", to: :is_read_only, render_default: true
            map "defaultValue", to: :default_value
          end

          def self.from_uml(uml_attr, owner, id_generator:, definition:,
stereotypes:)
            new(
              id: id_generator.attribute_id(uml_attr, owner),
              name: uml_attr.name,
              type: uml_attr.type,
              visibility: uml_attr.visibility,
              owner: id_generator.class_id(owner),
              owner_name: owner.name,
              cardinality: SpaCardinality.from_uml(uml_attr.cardinality),
              definition: definition,
              stereotypes: stereotypes,
              is_static: uml_attr.is_static,
              is_read_only: uml_attr.is_read_only,
              default_value: uml_attr.default,
            )
          end
        end
      end
    end
  end
end
