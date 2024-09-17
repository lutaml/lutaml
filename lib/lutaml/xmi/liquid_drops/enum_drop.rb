# frozen_string_literal: true

module Lutaml
  module XMI
    class EnumDrop < Liquid::Drop
      def initialize(model) # rubocop:disable Lint/MissingSuper
        @model = model
      end

      def xmi_id
        @model[:xmi_id]
      end

      def name
        @model[:name]
      end

      def values
        @model[:values].map do |value|
          ::Lutaml::XMI::EnumOwnedLiteralDrop.new(value)
        end
      end

      def definition
        @model[:definition]
      end

      def stereotype
        @model[:stereotype]
      end
    end
  end
end
