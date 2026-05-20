# frozen_string_literal: true

module Lutaml
  module Uml
    class Enum < Classifier
      skip_reference_registration

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
