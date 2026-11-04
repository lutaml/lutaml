module Expressir
  module Model
    module DataTypes
      # Specified in ISO 10303-11:2004
      # - section 8.1.2 Real data type
      class Real < ModelElement
        attribute :precision, ModelElement
        attribute :_class, :string, default: -> { self.class.name }

        key_value do
          map "_class", to: :_class, render_default: true
          map "precision", to: :precision
        end
      end
    end
  end
end
