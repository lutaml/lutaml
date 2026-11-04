module Expressir
  module Model
    module Declarations
      # Specified in ISO 10303-11:2004
      # - section 9.2.1 Attributes
      class DerivedAttribute < Attribute
        include Identifier

        DERIVED = "DERIVED".freeze

        attribute :kind, :string, default: -> { DERIVED }
        attribute :_class, :string, default: -> { self.class.name }

        key_value do
          map "_class", to: :_class, render_default: true
          map "kind", to: :kind, render_default: true
          map "supertype_attribute", to: :supertype_attribute
          map "optional", to: :optional
          map "type", to: :type
          map "expression", to: :expression
        end
      end
    end
  end
end
