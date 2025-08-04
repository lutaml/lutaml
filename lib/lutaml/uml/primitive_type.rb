# frozen_string_literal: true

module Lutaml
  module Uml
    class PrimitiveType < DataType
      attribute :keyword, :string, default: "primitive"

      yaml do
        map "keyword", to: :keyword
      end
    end
  end
end
