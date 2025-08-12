# frozen_string_literal: true

module Lutaml
  module XMI
    class ConnectorDrop < Liquid::Drop
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
        @model.name
      end

      def type
        @model&.properties&.ea_type
      end

      def documentation
        @model&.documentation&.value
      end

      def ea_type
        @model&.properties&.ea_type
      end

      def direction
        @model&.properties&.direction
      end

      def source
        ::Lutaml::XMI::SourceTargetDrop.new(@model.source, @options)
      end

      def target
        ::Lutaml::XMI::SourceTargetDrop.new(@model.target, @options)
      end

      def recognized?
        !!@id_name_mapping[@model.source.idref] &&
          !!@id_name_mapping[@model.target.idref]
      end
    end
  end
end
