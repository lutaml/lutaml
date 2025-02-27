# frozen_string_literal: true

module Lutaml
  module XMI
    class KlassDrop < Liquid::Drop
      include Parsers::XMIBase

      def initialize(model, guidance = nil, options = {}) # rubocop:disable Lint/MissingSuper,Metrics/AbcSize,Metrics/CyclomaticComplexity,Metrics/MethodLength,Metrics/PerceivedComplexity
        @model = model
        @guidance = guidance
        @options = options
        @xmi_root_model = options[:xmi_root_model]
        @xmi_cache = options[:xmi_cache]

        @package = model&.packaged_element&.find do |e|
          e.type?("uml:Package")
        end

        @owned_attributes = model&.owned_attribute&.select do |attr|
          attr.type?("uml:Property")
        end

        if @xmi_root_model
          @matched_element = @xmi_root_model&.extension&.elements&.element&.find do |e| # rubocop:disable Layout/LineLength,Style/SafeNavigationChainLength
            e.idref == @model.id
          end
        end

        if guidance
          @klass_guidance = guidance["classes"].find do |klass|
            klass["name"] == name || klass["name"] == absolute_path
          end
        end
      end

      def xmi_id
        @model.id
      end

      def name
        @model.name
      end

      def absolute_path
        "#{@options[:absolute_path]}::#{name}"
      end

      def package
        ::Lutaml::XMI::PackageDrop.new(
          @package,
          @guidance,
          @options.merge(
            {
              absolute_path: "#{@options[:absolute_path]}::#{name}",
            },
          ),
        )
      end

      def type
        @model.type.split(":").last
      end

      def attributes
        @owned_attributes.map do |owned_attr|
          if @options[:with_assoc] || owned_attr.association.nil?
            ::Lutaml::XMI::AttributeDrop.new(owned_attr, @options)
          end
        end.compact
      end

      def associations # rubocop:disable Metrics/AbcSize,Metrics/CyclomaticComplexity,Metrics/PerceivedComplexity,Metrics/MethodLength
        return if !@matched_element ||
          !@matched_element.links ||
          @matched_element.links.association.empty?

        @matched_element.links.association.map do |assoc|
          link_member = assoc.start == xmi_id ? "end" : "start"
          link_owner_name = link_member == "start" ? "end" : "start"

          member_end, member_end_type, member_end_cardinality,
            member_end_attribute_name, member_end_xmi_id =
            serialize_member_type(xmi_id, assoc, link_member)

          owner_end = serialize_owned_type(xmi_id, assoc, link_owner_name)

          if member_end && ((member_end_type != "aggregation") ||
            (member_end_type == "aggregation" && member_end_attribute_name))

            doc_node_name = (link_member == "start" ? "source" : "target")
            definition = fetch_definition_node_value(assoc.id, doc_node_name)

            ::Lutaml::XMI::AssociationDrop.new(
              xmi_id: assoc.id,
              member_end: member_end,
              member_end_type: member_end_type,
              member_end_cardinality: member_end_cardinality,
              member_end_attribute_name: member_end_attribute_name,
              member_end_xmi_id: member_end_xmi_id,
              owner_end: owner_end,
              owner_end_xmi_id: xmi_id,
              definition: definition,
            )
          end
        end.compact
      end

      def operations
        @model.owned_operation.map do |operation|
          if operation.association.nil?
            ::Lutaml::XMI::OperationDrop.new(operation)
          end
        end.compact
      end

      def constraints
        connector_node = fetch_connector(@model.id)
        return unless connector_node

        # In ea-xmi-2.5.1, constraints are moved to source/target under
        # connectors
        constraints = %i[source target].map do |st|
          connector_node.send(st).constraints.constraint
        end.flatten

        constraints.map do |constraint|
          ::Lutaml::XMI::ConstraintDrop.new(constraint)
        end
      end

      def generalization
        if @options[:with_gen] && @model.type?("uml:Class")
          generalization = serialize_generalization(@model)
          return {} if generalization.nil?

          ::Lutaml::XMI::GeneralizationDrop.new(
            generalization, @klass_guidance, @options
          )
        end
      end

      def has_guidance?
        !!@klass_guidance
      end

      def is_abstract # rubocop:disable Naming/PredicateName
        doc_node_attribute_value(@model.id, "isAbstract")
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
