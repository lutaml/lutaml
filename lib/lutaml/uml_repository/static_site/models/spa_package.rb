# frozen_string_literal: true

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
          attribute :stereotypes, :string, collection: true,
                                           initialize_empty: true
          attribute :classes, :string, collection: true, initialize_empty: true
          attribute :sub_packages, :string, collection: true,
                                            initialize_empty: true
          attribute :diagrams, :string, collection: true, initialize_empty: true
          attribute :parent, :string

          json do
            map "id", to: :id
            map "xmiId", to: :xmi_id
            map "name", to: :name
            map "path", to: :path
            map "definition", to: :definition
            map "stereotypes", to: :stereotypes, render_empty: true
            map "classes", to: :classes, render_empty: true
            map "subPackages", to: :sub_packages, render_empty: true
            map "diagrams", to: :diagrams, render_empty: true
            map "parent", to: :parent
          end
        end
      end
    end
  end
end
