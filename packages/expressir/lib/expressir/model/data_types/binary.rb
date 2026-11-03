module Expressir
  module Model
    module DataTypes
      # Specified in ISO 10303-11:2004
      # - section 8.1.7 Binary data type
      class Binary < ModelElement
        attribute :width, ModelElement
        attribute :fixed, :boolean
        attribute :_class, :string, default: -> { self.class.name }

        key_value do
          map "_class", to: :_class, render_default: true
          map "width", to: :width
          map "fixed", to: :fixed
        end
      end
    end
  end
end
