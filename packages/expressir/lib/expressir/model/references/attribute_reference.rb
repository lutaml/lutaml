module Expressir
  module Model
    module References
      # Specified in ISO 10303-11:2004
      # - section 12.7.3 Attribute references
      class AttributeReference < ModelElement
        attribute :ref, ModelElement
        attribute :attribute, ModelElement
        attribute :_class, :string, default: -> { self.class.name }

        key_value do
          map "_class", to: :_class, render_default: true
          map "ref", to: :ref
          map "attribute", to: :attribute
        end
      end
    end
  end
end
