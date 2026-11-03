module Expressir
  module Model
    module DataTypes
      # Specified in ISO 10303-11:2004
      # - section 8.2.2 List data type
      class List < ModelElement
        attribute :bound1, ModelElement
        attribute :bound2, ModelElement
        attribute :unique, :boolean
        attribute :base_type, ModelElement
        attribute :_class, :string, default: -> { self.class.name }

        key_value do
          map "_class", to: :_class, render_default: true
          map "bound1", to: :bound1
          map "bound2", to: :bound2
          map "unique", to: :unique
          map "base_type", to: :base_type
        end
      end
    end
  end
end
