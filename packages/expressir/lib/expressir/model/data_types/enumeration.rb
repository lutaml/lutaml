module Expressir
  module Model
    module DataTypes
      # Specified in ISO 10303-11:2004
      # - section 8.4.1 Enumeration data type
      class Enumeration < ModelElement
        attribute :extensible, :boolean
        attribute :based_on, ModelElement
        attribute :items, EnumerationItem, collection: true, initialize_empty: true
        attribute :_class, :string, default: -> { self.class.name }

        key_value do
          map "_class", to: :_class, render_default: true
          map "extensible", to: :extensible
          map "based_on", to: :based_on
          map "items", to: :items
        end
      end
    end
  end
end
