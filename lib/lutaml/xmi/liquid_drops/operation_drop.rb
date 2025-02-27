# frozen_string_literal: true

module Lutaml
  module XMI
    class OperationDrop < Liquid::Drop
      include Parsers::XMIBase

      def initialize(model, options = {}) # rubocop:disable Lint/MissingSuper
        @model = model
        @options = options
        @xmi_root_model = options[:xmi_root_model]
        @xmi_cache = options[:xmi_cache]
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
