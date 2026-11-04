module Expressir
  module Model
    module Statements
      # Specified in ISO 10303-11:2004
      # - section 13.5 Compound statement
      class Compound < ModelElement
        include Statement

        collection_attributes :statements
        attribute :statements, ModelElement, collection: true, initialize_empty: true
        attribute :_class, :string, default: -> { self.class.name }

        key_value do
          map "_class", to: :_class, render_default: true
          map "untagged_remarks", to: :untagged_remarks
          map "statements", to: :statements
        end
      end
    end
  end
end
