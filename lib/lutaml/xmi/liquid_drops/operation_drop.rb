# frozen_string_literal: true

module Lutaml
  module XMI
    class OperationDrop < Liquid::Drop
      def initialize(model) # rubocop:disable Lint/MissingSuper
        @model = model
      end

      def id
        @model[:id]
      end

      def xmi_id
        @model[:xmi_id]
      end

      def name
        @model[:name]
      end

      def definition
        @model[:definition]
      end
    end
  end
end
