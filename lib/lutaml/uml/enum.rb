# frozen_string_literal: true

module Lutaml
  module Uml
    class Enum < Classifier
      attribute :attributes, TopElementAttribute, collection: true,
                                                  default: -> { [] }
      attribute :modifier, :string
      attribute :keyword, :string, default: "enumeration"
      attribute :values, Value, collection: true, default: -> { [] }
      attribute :methods, :string, collection: true, default: -> { [] }

      yaml do
        map "attributes", to: :attributes
        map "modifier", to: :modifier
        map "keyword", to: :keyword
        map "values", to: :values
        map "methods", to: :methods
      end
    end
  end
end
