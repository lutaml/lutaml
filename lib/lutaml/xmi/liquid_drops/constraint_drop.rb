# frozen_string_literal: true

module Lutaml
  module XMI
    class ConstraintDrop < Liquid::Drop
      def initialize(model) # rubocop:disable Lint/MissingSuper
        @model = model
      end

      def name
        @model[:name]
      end

      def type
        @model[:type]
      end

      def weight
        @model[:weight]
      end

      def status
        @model[:status]
      end
    end
  end
end
