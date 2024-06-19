# frozen_string_literal: true

module Lutaml
  module Uml
    class PrimitiveType < DataType
      attr_reader :keyword

      def initialize(attributes = {})
        super
        @keyword = "primitive"
      end
    end
  end
end
