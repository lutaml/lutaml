# frozen_string_literal: true

module Lutaml
  module Xmi
    module Parsers
      module XmiBase
        # Association/connector serialization helpers used by Pipeline C

        # @param link_id [String]
        # @return [Lutaml::Model::Serializable]
        # @note xpath %(//connector[@xmi:idref="#{link_id}"])
        def fetch_connector(link_id)
          xmi_index.find_connector(link_id)
        end

        # @param link_id [String]
        # @param node_name [String] source or target
        # @return [String]
        # @note xpath
        #   %(//connector[@xmi:idref="#{link_id}"]/#{node_name}/documentation)
        def fetch_definition_node_value(link_id, node_name)
          connector_node = fetch_connector(link_id)
          return nil unless connector_node

          node = connector_node.send(node_name.to_sym)
          return nil unless node

          documentation = node.documentation

          if documentation.is_a?(::Xmi::Sparx::Element::Documentation)
            documentation&.value
          else
            documentation
          end
        end

        # @param owner_xmi_id [String]
        # @param link [Lutaml::Model::Serializable]
        # @param link_member_name [String]
        # @return [String]
        def serialize_owned_type(owner_xmi_id, link, linke_owner_name)
          case link
          when ::Xmi::Sparx::Element::NoteLink
            return
          when ::Xmi::Sparx::Element::Generalization
            owner_end, _owner_end_type, _owner_xmi_id =
              generalization_association(owner_xmi_id, link)
            return owner_end
          end

          xmi_id = link.send(linke_owner_name.to_sym)
          lookup_entity_name(xmi_id) || connector_source_name(xmi_id)
        end

        # @param owner_xmi_id [String]
        # @param link [Lutaml::Model::Serializable]
        # @return [Array<String, String>]
        def serialize_member_end(owner_xmi_id, link) # rubocop:disable Metrics/MethodLength,Metrics/AbcSize,Metrics/CyclomaticComplexity
          case link.name
          when "NoteLink"
            return
          when "Generalization"
            return generalization_association(owner_xmi_id, link)
          end

          xmi_id = link.start
          source_or_target = :source

          if link.start == owner_xmi_id
            xmi_id = link.end
            source_or_target = :target
          end

          connector = fetch_connector(link.id)
          ea_type = connector&.properties&.ea_type
          member_end_type = ea_type&.downcase

          member_end = member_end_name(xmi_id, source_or_target, link)
          [member_end, member_end_type, xmi_id]
        end

        # @param xmi_id [String]
        # @param source_or_target [Symbol]
        # @return [String]
        def member_end_name(xmi_id, source_or_target, link) # rubocop:disable Metrics/MethodLength
          connector_label = connector_labels(xmi_id, source_or_target)
          entity_name = lookup_entity_name(xmi_id)
          connector_name = connector_name_by_source_or_target(
            xmi_id, source_or_target
          )

          case link
          when ::Xmi::Sparx::Element::Aggregation
            connector_label || entity_name || connector_name
          else
            entity_name || connector_name
          end
        end

        # @param owner_xmi_id [String]
        # @param link [Lutaml::Model::Serializable]
        # @param link_member_name [String]
        # @return [Array<String, String, Hash, String, String>]
        def serialize_member_type(owner_xmi_id, link, link_member_name) # rubocop:disable Metrics/MethodLength,Metrics/AbcSize
          member_end, member_end_type, xmi_id =
            serialize_member_end(owner_xmi_id, link)

          if link.is_a?(::Xmi::Sparx::Element::Association)
            connector_type = link_member_name == "start" ? "source" : "target"
            member_end_cardinality, member_end_attribute_name =
              fetch_assoc_connector(link.id, connector_type)
          else
            member_end_cardinality, member_end_attribute_name =
              fetch_owned_attribute_node(xmi_id)
          end

          if fetch_connector_name(link.id)
            member_end = fetch_connector_name(link.id)
          end

          [member_end, member_end_type, member_end_cardinality,
           member_end_attribute_name, xmi_id]
        end

        def fetch_connector_name(link_id)
          connector = fetch_connector(link_id)
          connector&.name
        end

        # @param link_id [String]
        # @param connector_type [String]
        # @return [Array<Hash, String>]
        # @note xpath %(//connector[@xmi:idref="#{link_id}"]/#{connector_type})
        def fetch_assoc_connector(link_id, connector_type) # rubocop:disable Metrics/AbcSize,Metrics/MethodLength,Metrics/CyclomaticComplexity,Metrics/PerceivedComplexity
          connector = fetch_connector(link_id)
          return [nil, nil] unless connector

          assoc_connector = connector.send(connector_type.to_sym)

          if assoc_connector
            assoc_connector_type = assoc_connector.type
            if assoc_connector_type&.multiplicity
              cardinality = assoc_connector_type.multiplicity.split("..")
              cardinality.unshift("1") if cardinality.length == 1
              min, max = cardinality
            end

            assoc_connector_role = assoc_connector.role
            attribute_name = assoc_connector.model.name if assoc_connector_role
            cardinality = cardinality_min_max_value(min, max)
          end

          [cardinality, attribute_name]
        end

        # @param owner_xmi_id [String]
        # @param link [Lutaml::Model::Serializable]
        # @return [Array<String, String, Hash, String, String>]
        # @note match return value of serialize_member_type
        def generalization_association(owner_xmi_id, link) # rubocop:disable Metrics/MethodLength
          member_end_type = "generalization"
          xmi_id = link.start
          source_or_target = :source

          if link.start == owner_xmi_id
            member_end_type = "inheritance"
            xmi_id = link.end
            source_or_target = :target
          end

          member_end = member_end_name(xmi_id, source_or_target, link)

          [member_end, member_end_type, xmi_id]
        end

        # Multiple items if search type is idref.  Should search association?
        # @param xmi_id [String]
        # @return [Array<Hash, String>]
        # @note xpath
        #   %(//ownedAttribute[@association]/type[@xmi:id ref="#{xmi_id}"])
        def fetch_owned_attribute_node(xmi_id)
          oa = xmi_index.find_owned_attrs_by_type(xmi_id)
            .find { |a| !!a.association }

          if oa
            cardinality = cardinality_min_max_value(
              oa.lower_value&.value, oa.upper_value&.value
            )
            oa_name = oa.name
          end

          [cardinality, oa_name]
        end

        # @param xmi_id [String]
        # @param source_or_target [String]
        # @return [String]
        def connector_node_by_id(xmi_id, source_or_target)
          connector_lookup[[source_or_target.to_sym, xmi_id]]
        end

        # Lazy-built hash index for O(1) connector lookups
        # @return [Hash] Mapping of [direction, idref] => connector
        def connector_lookup
          @connector_lookup ||= begin
            lookup = {}
            connectors = @xmi_root_model.extension&.connectors&.connector || []
            connectors.each do |con|
              %i[source target].each do |dir|
                idref = con.send(dir)&.idref
                lookup[[dir, idref]] = con if idref
              end
            end
            lookup
          end
        end

        # @param xmi_id [String]
        # @param source_or_target [String]
        # @return [String]
        def connector_name_by_source_or_target(xmi_id, source_or_target) # rubocop:disable Metrics/AbcSize
          node = connector_node_by_id(xmi_id, source_or_target)
          return node.name if node&.name

          return if node.nil? ||
            node.send(source_or_target.to_sym).nil? ||
            node.send(source_or_target.to_sym).model.nil?

          node.send(source_or_target.to_sym).model.name
        end

        # @param xmi_id [String]
        # @param source_or_target [String]
        # @return [String]
        def connector_labels(xmi_id, source_or_target)
          node = connector_node_by_id(xmi_id, source_or_target)
          return if node.nil?

          node.labels&.rt || node.labels&.lt
        end

        # @param xmi_id [String]
        # @return [String]
        # @note xpath %(//source[@xmi:idref="#{xmi_id}"]/model)
        def connector_source_name(xmi_id)
          connector_name_by_source_or_target(xmi_id, :source)
        end
      end
    end
  end
end
