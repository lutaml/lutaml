# frozen_string_literal: true

module Lutaml
  module UmlRepository
    module StaticSite
      module Models
        # Forward declaration for recursive structure
        class SpaPackageTreeNode < SpaBase
          attribute :id, :string
          attribute :name, :string
          attribute :path, :string
          attribute :stereotypes, :string, collection: true, default: -> { [] }
          attribute :class_count, :integer, default: 0
          attribute :classes, SpaTreeClassRef, collection: true,
                                               default: -> { [] }
          attribute :children, SpaPackageTreeNode, collection: true,
                                                   default: -> { [] }

          json do
            map "id", to: :id
            map "name", to: :name
            map "path", to: :path
            map "stereotypes", to: :stereotypes
            map "classCount", to: :class_count
            map "classes", to: :classes
            map "children", to: :children
          end
        end
      end
    end
  end
end
