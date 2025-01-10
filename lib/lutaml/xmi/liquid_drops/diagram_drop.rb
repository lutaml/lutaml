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

      def package_id
        @model[:package_id]
      end

      def package_name
        @model[:package_name]
      end
    end
  end
end
