# frozen_string_literal: true

module Lutaml
  module XMI
    class DiagramDrop < Liquid::Drop
      def initialize(model) # rubocop:disable Lint/MissingSuper
        @model = model
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
