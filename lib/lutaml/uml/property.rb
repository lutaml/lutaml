# frozen_string_literal: true

module Lutaml
  module Uml
    class Property < TopElement
      attribute :type, :string
      attribute :aggregation, :string
      attribute :association, :string
      attribute :is_derived, :boolean, default: false
      attribute :visibility, :string, default: "public"
      attribute :lowerValue, :string, default: "1"
      attribute :upperValue, :string, default: "1"

      yaml do
        map "type", to: :type
        map "aggregation", to: :aggregation
        map "association", to: :association
        map "is_derived", to: :is_derived
        map "visibility", to: :visibility
        map "lowerValue", to: :lowerValue
        map "upperValue", to: :upperValue
      end
    end
  end
end
