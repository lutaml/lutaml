# frozen_string_literal: true

module Lutaml
  module XMI
    class EnumDrop < Liquid::Drop
      include Parsers::XMIBase

      def initialize(model, options = {}) # rubocop:disable Lint/MissingSuper
        @model = model
        @options = options
        @xmi_root_model = options[:xmi_root_model]
        @id_name_mapping = options[:id_name_mapping]

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

      # @return name of the upper packaged element
      def upper_packaged_element
        if @options[:with_gen]
          find_upper_level_packaged_element(@model.id)
        end
      end

      def subtype_of
        find_subtype_of_from_owned_attribute_type(@model.id)
      end
    end
  end
end
