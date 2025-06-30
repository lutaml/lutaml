# frozen_string_literal: true

module Lutaml
  module XMI
    class AssociationDrop < Liquid::Drop
      include Parsers::XMIBase

      def initialize( # rubocop:disable Lint/MissingSuper,Metrics/ParameterLists,Metrics/MethodLength
        xmi_id:,
        member_end:,
        member_end_type:,
        member_end_cardinality:,
        member_end_attribute_name:,
        member_end_xmi_id:,
        owner_end:,
        owner_end_xmi_id:,
        definition:,
        options:
      )
        @xmi_id = xmi_id
        @member_end = member_end
        @member_end_type = member_end_type
        @member_end_cardinality = member_end_cardinality
        @member_end_attribute_name = member_end_attribute_name
        @member_end_xmi_id = member_end_xmi_id
        @owner_end = owner_end
        @owner_end_xmi_id = owner_end_xmi_id
        @definition = definition
        @options = options
        @xmi_root_model = options[:xmi_root_model]
        @id_name_mapping = options[:id_name_mapping]
      end

      def xmi_id
        @xmi_id
      end

      def member_end
        @member_end
      end

      def member_end_type
        @member_end_type
      end

      def member_end_cardinality
        ::Lutaml::XMI::CardinalityDrop.new(@member_end_cardinality)
      end

      def member_end_attribute_name
        @member_end_attribute_name
      end

      def member_end_xmi_id
        @member_end_xmi_id
      end

      def owner_end
        @owner_end
      end

      def owner_end_xmi_id
        @owner_end_xmi_id
      end

      def definition
        @definition
      end

      def connector
        connector = fetch_connector(@xmi_id)
        ::Lutaml::XMI::ConnectorDrop.new(connector, @options)
      end
    end
  end
end
