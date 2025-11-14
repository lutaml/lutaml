# frozen_string_literal: true

require_relative "classifier"
require_relative "top_element_attribute"
require_relative "value"

module Lutaml
  module Uml
    class Enum < Classifier
      attribute :attributes, TopElementAttribute, collection: true,
                                                  default: -> { [] }
      attribute :modifier, :string
      attribute :keyword, :string, default: "enumeration"
      attribute :values, Value, collection: true, default: -> { [] }
      yaml do
        map "attributes", to: :attributes
        map "modifier", to: :modifier
        map "keyword", to: :keyword
        map "values", to: :values
      end
    end
  end
end
