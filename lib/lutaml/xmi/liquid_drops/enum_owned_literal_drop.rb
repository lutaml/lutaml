# frozen_string_literal: true

module Lutaml
  module XMI
    class EnumOwnedLiteralDrop < Liquid::Drop
      def initialize(model) # rubocop:disable Lint/MissingSuper
        @model = model
      end

      def name
        @model[:name]
      end

      def type
        @model[:type]
      end

      def definition
        @model[:definition]
      end
    end
  end
end
