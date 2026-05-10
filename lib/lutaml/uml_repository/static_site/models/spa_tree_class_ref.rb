# frozen_string_literal: true

require_relative "spa_base"

module Lutaml
  module UmlRepository
    module StaticSite
      module Models
        class SpaTreeClassRef < SpaBase
          attribute :id, :string
          attribute :name, :string
          attribute :stereotypes, :string, collection: true, default: -> { [] }

          json do
            map "id", to: :id
            map "name", to: :name
            map "stereotypes", to: :stereotypes
          end
        end
      end
    end
  end
end
