# frozen_string_literal: true

module Lutaml
  module XMI
    class EnumDrop < Liquid::Drop
      include Parsers::XMIBase

      def initialize(model, options = {}) # rubocop:disable Lint/MissingSuper
        @model = model
        @options = options
        @xmi_root_model = options[:xmi_root_model]
        @xmi_cache = options[:xmi_cache]

        @owned_literals = model&.owned_literal&.select do |owned_literal|
          owned_literal.type? "uml:EnumerationLiteral"
        end
      end

      def xmi_id
        @model.id
      end

      def name
        @model.name
      end

      def values
        @owned_literals.map do |owned_literal|
          ::Lutaml::XMI::EnumOwnedLiteralDrop.new(owned_literal, @options)
        end
      end

      def definition
        doc_node_attribute_value(@model.id, "documentation")
      end

      def stereotype
        doc_node_attribute_value(@model.id, "stereotype")
      end
    end
  end
end
