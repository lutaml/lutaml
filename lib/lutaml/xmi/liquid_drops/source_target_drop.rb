# frozen_string_literal: true

module Lutaml
  module XMI
    class SourceTargetDrop < Liquid::Drop
      include Parsers::XMIBase

      def initialize(model, options = {}) # rubocop:disable Lint/MissingSuper
        @model = model
        @options = options
        @xmi_root_model = options[:xmi_root_model]
        @id_name_mapping = options[:id_name_mapping]
      end

      def idref
        @model.idref
      end

      def name
        @model&.role&.name
      end

      def type
        @model&.model&.name
      end

      def documentation
        @model&.documentation&.value
      end

      def multiplicity
        @model&.type&.multiplicity
      end

      def aggregation
        @model&.type&.aggregation
      end

      def stereotype
        doc_node_attribute_value(@model.idref, "stereotype")
      end
    end
  end
end
