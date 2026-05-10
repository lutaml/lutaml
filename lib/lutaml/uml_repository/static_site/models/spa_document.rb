# frozen_string_literal: true

require_relative "spa_base"
require_relative "spa_metadata"
require_relative "spa_package_tree_node"
require_relative "spa_package"
require_relative "spa_class"
require_relative "spa_attribute"
require_relative "spa_association"
require_relative "spa_operation"
require_relative "spa_diagram"
require_relative "spa_search_entry"

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
