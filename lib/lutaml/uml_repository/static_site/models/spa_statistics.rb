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
            map "packages", to: :packages, render_default: true
            map "classes", to: :classes, render_default: true
            map "associations", to: :associations, render_default: true
            map "attributes", to: :attributes, render_default: true
            map "operations", to: :operations, render_default: true
          end
        end
      end
    end
  end
end
