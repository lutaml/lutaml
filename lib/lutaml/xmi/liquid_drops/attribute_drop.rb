# frozen_string_literal: true

module Lutaml
  module XMI
    class AttributeDrop < Liquid::Drop
      def initialize(model) # rubocop:disable Lint/MissingSuper
        @model = model
      end

      def id
        @model[:id]
      end

      def name
        @model[:name]
      end

      def type
        @model[:type]
      end

      def xmi_id
        @model[:xmi_id]
      end

      def is_derived
        @model[:is_derived]
      end

      def cardinality
        ::Lutaml::XMI::CardinalityDrop.new(@model[:cardinality])
      end

      def definition
        @model[:definition]
      end

      def association
        @model[:association]
      end

      def type_ns
        @model[:type_ns]
      end
    end
  end
end
