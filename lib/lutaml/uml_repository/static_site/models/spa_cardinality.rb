# frozen_string_literal: true

module Lutaml
  module UmlRepository
    module StaticSite
      module Models
        class SpaCardinality < SpaBase
          attribute :min, :string
          attribute :max, :string

          json do
            map "min", to: :min
            map "max", to: :max
          end

          def self.from_uml(uml_cardinality)
            return nil unless uml_cardinality

            new(
              min: uml_cardinality.min,
              max: uml_cardinality.max,
            )
          end
        end
      end
    end
  end
end
