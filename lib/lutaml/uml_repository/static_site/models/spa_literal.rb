# frozen_string_literal: true

require_relative "spa_base"

module Lutaml
  module UmlRepository
    module StaticSite
      module Models
        class SpaLiteral < SpaBase
          attribute :name, :string
          attribute :definition, :string

          json do
            map "name", to: :name
            map "definition", to: :definition
          end
        end
      end
    end
  end
end
