# frozen_string_literal: true

module Lutaml
  module UmlRepository
    module StaticSite
      module Models
        class SpaAssociationEnd < SpaBase
          attribute :klass, :string
          attribute :class_name, :string
          attribute :role, :string
          attribute :cardinality, SpaCardinality
          attribute :aggregation, :string

          json do
            map "class", to: :klass
            map "className", to: :class_name
            map "role", to: :role
            map "cardinality", to: :cardinality
            map "aggregation", to: :aggregation
          end
        end
      end
    end
  end
end
