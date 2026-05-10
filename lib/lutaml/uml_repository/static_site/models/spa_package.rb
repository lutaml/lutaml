# frozen_string_literal: true

require_relative "spa_base"

module Lutaml
  module UmlRepository
    module StaticSite
      module Models
        class SpaPackage < SpaBase
          attribute :id, :string
          attribute :xmi_id, :string
          attribute :name, :string
          attribute :path, :string
          attribute :definition, :string
          attribute :stereotypes, :string, collection: true, default: -> { [] }
          attribute :classes, :string, collection: true, default: -> { [] }
          attribute :sub_packages, :string, collection: true, default: -> { [] }
          attribute :diagrams, :string, collection: true, default: -> { [] }
          attribute :parent, :string

          json do
            map "id", to: :id
            map "xmiId", to: :xmi_id
            map "name", to: :name
            map "path", to: :path
            map "definition", to: :definition
            map "stereotypes", to: :stereotypes
            map "classes", to: :classes
            map "subPackages", to: :sub_packages
            map "diagrams", to: :diagrams
            map "parent", to: :parent
          end
        end
      end
    end
  end
end
