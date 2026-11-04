module Expressir
  module Model
    module Statements
      # Specified in ISO 10303-11:2004
      # - section 13.10 Return statement
      class Return < ModelElement
        include Statement

        attribute :expression, ModelElement
        attribute :_class, :string, default: -> { self.class.name }

        key_value do
          map "_class", to: :_class, render_default: true
          map "untagged_remarks", to: :untagged_remarks
          map "expression", to: :expression
        end
      end
    end
  end
end
