# frozen_string_literal: true

module Lutaml
  module UmlRepository
    module StaticSite
      module Models
        class SpaParameter < SpaBase
          attribute :name, :string
          attribute :type, :string
          attribute :direction, :string

          json do
            map "name", to: :name
            map "type", to: :type
            map "direction", to: :direction
          end
        end
      end
    end
  end
end
