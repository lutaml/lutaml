# frozen_string_literal: true

module Lutaml
  module XMI
    class DiagramDrop < Liquid::Drop
      include Parsers::XMIBase

      def initialize(model, options = {}) # rubocop:disable Lint/MissingSuper
        @model = model
        @options = options
        @xmi_root_model = options[:xmi_root_model]
        @id_name_mapping = options[:id_name_mapping]
      end

      def xmi_id
        @model.id
      end

      def name
        @model.properties.name
      end

      def definition
        @model.properties.documentation
      end

      def package_id
        @model.model.package if @options[:with_gen]
      end

      def package_name
        if @options[:with_gen] && package_id
          find_packaged_element_by_id(package_id)&.name
        end
      end
    end
  end
end
