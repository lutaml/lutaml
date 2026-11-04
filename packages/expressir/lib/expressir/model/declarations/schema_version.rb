module Expressir
  module Model
    module Declarations
      # Specified in ISO 10303-11:2004
      # - section 9.3 Schema
      class SchemaVersion < ModelElement
        attribute :value, :string
        attribute :items, SchemaVersionItem, collection: true, initialize_empty: true
        attribute :_class, :string, default: -> { self.class.name }

        key_value do
          map "_class", to: :_class, render_default: true
          map "value", to: :value
          map "items", to: :items
        end
      end
    end
  end
end
