# frozen_string_literal: true

module Lutaml
  module UmlRepository
    module StaticSite
      module Models
        class SpaDocument < SpaBase
          attribute :metadata, SpaMetadata
          attribute :package_tree, SpaPackageTreeNode
          attribute :packages, :hash, default: -> { {} }
          attribute :classes, :hash, default: -> { {} }
          attribute :attributes, :hash, default: -> { {} }
          attribute :associations, :hash, default: -> { {} }
          attribute :operations, :hash, default: -> { {} }
          attribute :diagrams, :hash, default: -> { {} }

          json do
            map "metadata", to: :metadata
            map "packageTree", to: :package_tree
            map "packages", to: :packages
            map "classes", to: :classes
            map "attributes", to: :attributes
            map "associations", to: :associations
            map "operations", to: :operations
            map "diagrams", to: :diagrams
          end
        end
      end
    end
  end
end
