# frozen_string_literal: true

require_relative "spa_base"

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
        end
      end
    end
  end
end
