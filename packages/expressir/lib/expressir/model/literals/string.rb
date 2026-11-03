module Expressir
  module Model
    module Literals
      # Specified in ISO 10303-11:2004
      # - section 7.5.4 String literal
      class String < ModelElement
        attribute :value, :string
        attribute :encoded, :boolean
        attribute :_class, :string, default: -> { self.class.name }

        key_value do
          map "_class", to: :_class, render_default: true
          map "value", to: :value,
                       value_map: { to: { nil: :empty, empty: :empty } }
          map "encoded", to: :encoded
        end
      end
    end
  end
end
