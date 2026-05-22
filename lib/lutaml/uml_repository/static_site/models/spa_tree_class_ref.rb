# frozen_string_literal: true

module Lutaml
  module UmlRepository
    module StaticSite
      module Models
        class SpaTreeClassRef < SpaBase
          attribute :id, :string
          attribute :name, :string
          attribute :stereotypes, :string, collection: true,
                                           initialize_empty: true

          json do
            map "id", to: :id
            map "name", to: :name
            map "stereotypes", to: :stereotypes, render_empty: true
          end
        end
      end
    end
  end
end
