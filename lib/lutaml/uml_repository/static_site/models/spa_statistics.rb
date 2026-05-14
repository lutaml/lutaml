# frozen_string_literal: true

module Lutaml
  module UmlRepository
    module StaticSite
      module Models
        class SpaStatistics < SpaBase
          attribute :packages, :integer, default: 0
          attribute :classes, :integer, default: 0
          attribute :associations, :integer, default: 0
          attribute :attributes, :integer, default: 0
          attribute :operations, :integer, default: 0

          json do
            map "packages", to: :packages
            map "classes", to: :classes
            map "associations", to: :associations
            map "attributes", to: :attributes
            map "operations", to: :operations
          end
        end
      end
    end
  end
end
