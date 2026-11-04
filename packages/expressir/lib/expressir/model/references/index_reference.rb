module Expressir
  module Model
    module References
      # Specified in ISO 10303-11:2004
      # - section 12.3.1 Binary indexing
      # - section 12.5.1 String indexing
      # - section 12.6.1 Aggregate indexing
      class IndexReference < ModelElement
        attribute :ref, ModelElement
        attribute :index1, ModelElement
        attribute :index2, ModelElement
        attribute :_class, :string, default: -> { self.class.name }

        key_value do
          map "_class", to: :_class, render_default: true
          map "ref", to: :ref
          map "index1", to: :index1
          map "index2", to: :index2
        end
      end
    end
  end
end
