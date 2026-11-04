module Expressir
  module Model
    module Expressions
      # Specified in ISO 10303-11:2004
      # - section 9.2.6 Implicit declarations
      class EntityConstructor < ModelElement
        child_attributes :parameters
        attribute :entity, ModelElement
        attribute :parameters, ModelElement, collection: true, initialize_empty: true
        attribute :_class, :string, default: -> { self.class.name }

        key_value do
          map "_class", to: :_class, render_default: true
          map "entity", to: :entity
          map "parameters", to: :parameters
        end
      end
    end
  end
end
