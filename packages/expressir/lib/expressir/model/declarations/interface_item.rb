module Expressir
  module Model
    module Declarations
      # Specified in ISO 10303-11:2004
      # - section 11 Interface specification
      class InterfaceItem < ModelElement
        include HasId

        attribute :ref, ModelElement
        attribute :id, :string
        attribute :_class, :string, default: -> { self.class.name }

        key_value do
          map "_class", to: :_class, render_default: true
          map "ref", to: :ref
          map "id", to: :id
        end
      end
    end
  end
end
