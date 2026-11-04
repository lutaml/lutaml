module Expressir
  module Model
    module Declarations
      # Specified in ISO 10303-11:2004
      # - section 9.3 Schema
      class SchemaVersionItem < ModelElement
        attribute :name, :string
        attribute :value, :string
        attribute :_class, :string, default: -> { self.class.name }

        key_value do
          map "_class", to: :_class, render_default: true
          map "name", to: :name
          map "value", to: :value
        end
      end
    end
  end
end
