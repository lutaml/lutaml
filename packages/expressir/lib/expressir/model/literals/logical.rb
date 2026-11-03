module Expressir
  module Model
    module Literals
      # Specified in ISO 10303-11:2004
      # - section 7.5.5 Logical literal
      class Logical < ModelElement
        TRUE = "TRUE".freeze
        FALSE = "FALSE".freeze
        UNKNOWN = "UNKNOWN".freeze

        attribute :value, :string, values: %w[TRUE FALSE UNKNOWN]
        attribute :_class, :string, default: -> { self.class.name }

        key_value do
          map "_class", to: :_class, render_default: true
          map "value", to: :value
        end
      end
    end
  end
end
