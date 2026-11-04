module Expressir
  module Model
    module Expressions
      # Specified in ISO 10303-11:2004
      # - section 12.8 Function call
      class FunctionCall < ModelElement
        child_attributes :parameters
        attribute :function, ModelElement
        attribute :parameters, ModelElement, collection: true, initialize_empty: true
        attribute :_class, :string, default: -> { self.class.name }

        key_value do
          map "_class", to: :_class, render_default: true
          map "function", to: :function
          map "parameters", to: :parameters
        end
      end
    end
  end
end
