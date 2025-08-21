# frozen_string_literal: true

module Lutaml
  module Lml
    class AttributeValue
      attr_accessor :value

      def self.cast(value)
        value
      end

      def initialize(value = nil)
        @value = value
      end
    end
  end
end
