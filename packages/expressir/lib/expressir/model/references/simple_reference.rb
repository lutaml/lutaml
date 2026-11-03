module Expressir
  module Model
    module References
      # Specified in ISO 10303-11:2004
      # - section 12.7.1 Simple references
      class SimpleReference < ModelElement
        attribute :id, :string
        attribute :ref, ModelElement
        attribute :base_path, :string
        attribute :_class, :string, default: -> { self.class.name }

        key_value do
          map "_class", to: :_class, render_default: true
          map "id", to: :id
          map "ref", to: :ref
          map "base_path", to: :base_path
        end
      end
    end
  end
end
