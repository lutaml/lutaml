# frozen_string_literal: true

module Lutaml
  module XMI
    class EnumOwnedLiteralDrop < Liquid::Drop
      include Parsers::XMIBase

      def initialize(model, options = {}) # rubocop:disable Lint/MissingSuper
        @model = model
        @options = options
        @xmi_root_model = options[:xmi_root_model]
        @id_name_mapping = options[:id_name_mapping]
      end

      def name
        @model.name
      end

      def type
        uml_type_id = @model&.uml_type&.idref
        lookup_entity_name(uml_type_id) || uml_type_id
      end

      def definition
        lookup_attribute_documentation(@model.id)
      end
    end
  end
end
