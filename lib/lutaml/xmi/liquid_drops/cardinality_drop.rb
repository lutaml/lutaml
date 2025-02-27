# frozen_string_literal: true

module Lutaml
  module XMI
    class CardinalityDrop < Liquid::Drop
      include Parsers::XMIBase

      def initialize(model) # rubocop:disable Lint/MissingSuper
        @model = model
      end

      def min
        return @model[:min] if @model.is_a?(Hash)

        @model.lower_value&.value
      end

      def max
        return @model[:max] if @model.is_a?(Hash)

        @model.upper_value&.value
      end
    end
  end
end
