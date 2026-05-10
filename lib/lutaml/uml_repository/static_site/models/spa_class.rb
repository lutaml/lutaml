# frozen_string_literal: true

require_relative "spa_base"
require_relative "spa_literal"
require_relative "spa_inherited_attribute"
require_relative "spa_inherited_association"

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
          attribute :stereotypes, :string, collection: true, default: -> { [] }
          attribute :definition, :string
          attribute :attributes, :string, collection: true, default: -> { [] }
          attribute :operations, :string, collection: true, default: -> { [] }
          attribute :associations, :string, collection: true, default: -> { [] }
          attribute :generalizations, :string, collection: true, default: -> { [] }
          attribute :specializations, :string, collection: true, default: -> { [] }
          attribute :is_abstract, :boolean, default: false
          attribute :literals, SpaLiteral, collection: true, default: -> { [] }
          attribute :inherited_attributes, SpaInheritedAttribute, collection: true,
                                                                 default: -> { [] }
          attribute :inherited_associations, SpaInheritedAssociation, collection: true,
                                                                      default: -> { [] }

          json do
            map "id", to: :id
            map "xmiId", to: :xmi_id
            map "name", to: :name
            map "qualifiedName", to: :qualified_name
            map "type", to: :type
            map "package", to: :package
            map "stereotypes", to: :stereotypes
            map "definition", to: :definition
            map "attributes", to: :attributes
            map "operations", to: :operations
            map "associations", to: :associations
            map "generalizations", to: :generalizations
            map "specializations", to: :specializations
            map "isAbstract", to: :is_abstract
            map "literals", to: :literals
            map "inheritedAttributes", to: :inherited_attributes
            map "inheritedAssociations", to: :inherited_associations
          end
        end
      end
    end
  end
end
