# frozen_string_literal: true

module Lutaml
  module UmlRepository
    module StaticSite
      module Models
        class SpaPackageTreeNode < SpaBase
          attribute :id, :string
          attribute :name, :string
          attribute :path, :string
          attribute :stereotypes, :string, collection: true,
                                           initialize_empty: true
          attribute :class_count, :integer, default: 0
          attribute :classes, SpaTreeClassRef, collection: true,
                                               initialize_empty: true
          attribute :children, SpaPackageTreeNode, collection: true,
                                                   initialize_empty: true

          json do
            map "id", to: :id
            map "name", to: :name
            map "path", to: :path
            map "stereotypes", to: :stereotypes, render_empty: true
            map "classCount", to: :class_count, render_default: true
            map "classes", to: :classes, render_empty: true
            map "children", to: :children, render_empty: true
          end
        end
      end
    end
  end
end
