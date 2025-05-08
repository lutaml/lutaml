# frozen_string_literal: true

module Lutaml
  module XMI
    class OperationDrop < Liquid::Drop
      include Parsers::XMIBase

      def initialize(model, options = {}) # rubocop:disable Lint/MissingSuper
        @model = model
        @options = options
        @xmi_root_model = options[:xmi_root_model]
        @id_name_mapping = options[:id_name_mapping]
      end

      def id
        @model.id
      end

      def xmi_id
        uml_type = @model.uml_type.first
        uml_type&.idref
      end

      def name
        @model.name
      end

      def definition
        lookup_attribute_documentation(@model.id)
      end
    end
  end
end
