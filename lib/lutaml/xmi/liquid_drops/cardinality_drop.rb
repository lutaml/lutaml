# frozen_string_literal: true

module Lutaml
  module XMI
    class CardinalityDrop < Liquid::Drop
      def initialize(model) # rubocop:disable Lint/MissingSuper
        @model = model
      end

      def min
        @model["min"]
      end

      def max
        @model["max"]
      end
    end
  end
end
