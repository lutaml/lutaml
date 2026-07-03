# frozen_string_literal: true

module Lutaml
  module UmlRepository
    module StaticSite
      module Models
        class SpaClass < SpaBase
          attribute :id, :string
          attribute :xmi_id, :string
          attribute :name, :string
          attribute :qualified_name, :string
          attribute :type, :string
          attribute :package, :string
          attribute :stereotypes, :string, collection: true,
                                           initialize_empty: true
          attribute :definition, :string
          attribute :attributes, :string, collection: true,
                                          initialize_empty: true
          attribute :operations, :string, collection: true,
                                          initialize_empty: true
          attribute :associations, :string, collection: true,
                                            initialize_empty: true
          attribute :generalizations, :string, collection: true,
                                               initialize_empty: true
          attribute :specializations, :string, collection: true,
                                               initialize_empty: true
          attribute :is_abstract, :boolean, default: false
          attribute :literals, SpaLiteral, collection: true,
                                           initialize_empty: true
          attribute :inherited_attributes, SpaInheritedAttribute, collection: true,
                                                                  initialize_empty: true
          attribute :inherited_associations, SpaInheritedAssociation, collection: true,
                                                                      initialize_empty: true

          json do
            map "id", to: :id
            map "xmiId", to: :xmi_id
            map "name", to: :name
            map "qualifiedName", to: :qualified_name
            map "type", to: :type
            map "package", to: :package
            map "stereotypes", to: :stereotypes, render_empty: true
            map "definition", to: :definition
            map "attributes", to: :attributes, render_empty: true
            map "operations", to: :operations, render_empty: true
            map "associations", to: :associations, render_empty: true
            map "generalizations", to: :generalizations, render_empty: true
            map "specializations", to: :specializations, render_empty: true
            map "isAbstract", to: :is_abstract, render_default: true
            map "literals", to: :literals, render_empty: true
            map "inheritedAttributes", to: :inherited_attributes,
                                       render_empty: true
            map "inheritedAssociations", to: :inherited_associations,
                                         render_empty: true
          end
        end
      end
    end
  end
end
