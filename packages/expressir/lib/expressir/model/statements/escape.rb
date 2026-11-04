module Expressir
  module Model
    module Statements
      # Specified in ISO 10303-11:2004
      # - section 13.6 Escape statement
      class Escape < ModelElement
        include Statement

        attribute :_class, :string, default: -> { self.class.name }

        key_value do
          map "_class", to: :_class, render_default: true
          map "untagged_remarks", to: :untagged_remarks
        end
      end
    end
  end
end
