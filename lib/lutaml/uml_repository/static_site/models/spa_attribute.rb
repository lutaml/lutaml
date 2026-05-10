# frozen_string_literal: true

require_relative "spa_base"
require_relative "spa_cardinality"

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
          attribute :stereotypes, :string, collection: true, default: -> { [] }
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
            map "stereotypes", to: :stereotypes
            map "isStatic", to: :is_static
            map "isReadOnly", to: :is_read_only
            map "defaultValue", to: :default_value
          end
        end
      end
    end
  end
end
