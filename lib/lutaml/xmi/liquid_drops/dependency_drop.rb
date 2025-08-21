# frozen_string_literal: true

module Lutaml
  module XMI
    class DependencyDrop < Liquid::Drop
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

      def name
        @model.name
      end

      def ea_type
        @model&.properties&.ea_type
      end

      def documentation
        @model&.documentation&.value
      end

      def connector
        connector = fetch_connector(@model.id)
        ::Lutaml::XMI::ConnectorDrop.new(connector, @options)
      end
    end
  end
end
