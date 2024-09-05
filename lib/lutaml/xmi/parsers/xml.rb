require "nokogiri"
require "htmlentities"
require "lutaml/uml/has_attributes"
require "lutaml/uml/document"
require "lutaml/xmi"
require "xmi"

module Lutaml
  module XMI
    module Parsers
      # Class for parsing .xmi schema files into ::Lutaml::Uml::Document
      class XML
        LOWER_VALUE_MAPPINGS = {
          "0" => "C",
          "1" => "M",
        }.freeze
        attr_reader :xmi_cache, :xmi_root_model

        class << self
          # @param xml [String] path to xml
          # @param options [Hash] options for parsing
          # @return [Lutaml::Uml::Document]
          def parse(xml, _options = {})
            xmi_model = get_xmi_model(xml)
            new.parse(xmi_model)
          end

          # @param xml [String] path to xml
          # @return [Hash]
          def serialize_xmi(xml)
            xmi_model = get_xmi_model(xml)
            new.serialize_xmi(xmi_model)
          end

          # @param xml [String] path to xml
          # @param name [String]
          # @return [Hash]
          def serialize_generalization_by_name(xml, name)
            xmi_model = get_xmi_model(xml)
            new.serialize_generalization_by_name(xmi_model, name)
          end

          private

          # @param xml [String]
          # @return [Shale::Mapper]
          def get_xmi_model(xml)
            Xmi::Sparx::SparxRoot.parse_xml(File.read(xml))
          end
        end

        # @param xmi_model [Shale::Mapper]
        # @return [Lutaml::Uml::Document]
        def parse(xmi_model)
          @xmi_cache = {}
          @xmi_root_model = xmi_model
          serialized_hash = serialize_xmi(xmi_model)

          ::Lutaml::Uml::Document.new(serialized_hash)
        end

        # @param xmi_model [Shale::Mapper]
        # return [Hash]
        def serialize_xmi(xmi_model)
          @xmi_cache = {}
          @xmi_root_model = xmi_model
          serialize_to_hash(xmi_model)
        end

        # @param xmi_model [Shale::Mapper]
        # @param name [String]
        # @return [Hash]
        def serialize_generalization_by_name(xmi_model, name)
          @xmi_cache = {}
          @xmi_root_model = xmi_model
          klass = find_klass_packaged_element_by_name(name)
          serialize_generalization(klass)
        end

        private

        # @param xmi_model [Shale::Mapper]
        # @return [Hash]
        # @note xpath: //uml:Model[@xmi:type="uml:Model"]
        def serialize_to_hash(xmi_model)
          model = xmi_model.model
          {
            name: model.name,
            packages: serialize_model_packages(model),
          }
        end

        # @param model [Shale::Mapper]
        # @return [Array<Hash>]
        # @note xpath ./packagedElement[@xmi:type="uml:Package"]
        def serialize_model_packages(model)
          model.packaged_element.select do |e|
            e.type?("uml:Package")
          end.map do |package|
            {
              xmi_id: package.id,
              name: get_package_name(package),
              classes: serialize_model_classes(package, model),
              enums: serialize_model_enums(package),
              data_types: serialize_model_data_types(package),
              diagrams: serialize_model_diagrams(package.id),
              packages: serialize_model_packages(package),
              definition: doc_node_attribute_value(package.id, "documentation"),
              stereotype: doc_node_attribute_value(package.id, "stereotype"),
            }
          end
        end

        def get_package_name(package)
          return package.name unless package.name.nil?

          connector = fetch_connector(package.id)
          if connector.target&.model && connector.target.model&.name
            return "#{connector.target.model.name} " \
                   "(#{package.type.split(':').last})"
          end

          "unnamed"
        end

        # @param package [Shale::Mapper]
        # @param model [Shale::Mapper]
        # @return [Array<Hash>]
        # @note xpath ./packagedElement[@xmi:type="uml:Class" or
        #                               @xmi:type="uml:AssociationClass"]
        def serialize_model_classes(package, model)
          package.packaged_element.select do |e|
            e.type?("uml:Class") || e.type?("uml:AssociationClass") ||
              e.type?("uml:Interface")
          end.map do |klass|
            {
              xmi_id: klass.id,
              name: klass.name,
              package: model,
              type: klass.type.split(":").last,
              attributes: serialize_class_attributes(klass),
              associations: serialize_model_associations(klass.id),
              operations: serialize_class_operations(klass),
              constraints: serialize_class_constraints(klass.id),
              is_abstract: doc_node_attribute_value(klass.id, "isAbstract"),
              definition: doc_node_attribute_value(klass.id, "documentation"),
              stereotype: doc_node_attribute_value(klass.id, "stereotype"),
            }
          end
        end

        # @param klass [Shale::Mapper]
        # # @return [Hash]
        def serialize_generalization(klass)
          general_hash, next_general_node_id = get_top_level_general_hash(klass)
          return general_hash unless next_general_node_id

          general_hash[:general] = serialize_generalization_attributes(
            next_general_node_id,
          )

          general_hash
        end

        # @param klass [Shale::Mapper]
        # @return [Array<Hash>]
        def get_top_level_general_hash(klass) # rubocop:disable Metrics/AbcSize
          general_hash, next_general_node_id = get_general_hash(klass.id)
          general_hash[:name] = klass.name
          general_hash[:type] = klass.type
          general_hash[:definition] = lookup_attribute_documentation(klass.id)
          general_hash[:stereotype] = doc_node_attribute_value(
            klass.id, "stereotype"
          )

          # update_inherited_attributes(general_hash)
          # update_gen_attributes(general_hash)

          [general_hash, next_general_node_id]
        end

        def update_gen_attributes(general_hash)
          general_hash[:gen_attributes] = serialize_gen_attributes
        end

        def update_inherited_attributes(general_hash)
          general_hash[:gml_attributes] = serialize_gml_attributes
          general_hash[:core_attributes] = serialize_core_attributes
        end

        # @param xmi_id [String]
        # @param model [Shale::Mapper]
        # @return [Array<Hash>]
        # @note get generalization node and its owned attributes
        def serialize_generalization_attributes(general_id)
          general_hash, next_general_node_id = get_general_hash(general_id)

          if next_general_node_id
            general_hash[:general] = serialize_generalization_attributes(
              next_general_node_id,
            )
          end

          general_hash
        end

        # @param xmi_id [String]
        # @return [Shale::Mapper]
        def get_general_node(xmi_id)
          find_packaged_element_by_id(xmi_id)
        end

        # @param general_node [Shale::Mapper]
        # # @return [Hash]
        def get_general_attributes(general_node)
          serialize_class_attributes(general_node, with_assoc: true)
        end

        # @param general_node [Shale::Mapper]
        # @return [String]
        def get_next_general_node_id(general_node)
          general_node.generalization.first&.general
        end

        # @param general_id [String]
        # @return [Array<Hash>]
        def get_general_hash(general_id)
          general_node = get_general_node(general_id)
          general_node_attrs = get_general_attributes(general_node)
          general_upper_klass = find_upper_level_packaged_element(general_id)
          next_general_node_id = get_next_general_node_id(general_node)

          [
            {
              general_id: general_id,
              general_name: general_node.name,
              general_attributes: general_node_attrs,
              general_upper_klass: general_upper_klass,
              general: {},
            },
            next_general_node_id,
          ]
        end

        # @param id [String]
        # @return [Shale::Mapper]
        def find_packaged_element_by_id(id)
          all_packaged_elements.find { |e| e.id == id }
        end

        # @param id [String]
        # @return [Shale::Mapper]
        def find_upper_level_packaged_element(klass_id)
          upper_klass = all_packaged_elements.find do |e|
            e.packaged_element.find { |pe| pe.id == klass_id }
          end
          upper_klass&.name
        end

        # @param name [String]
        # @return [Shale::Mapper]
        def find_klass_packaged_element_by_name(name)
          all_packaged_elements.find do |e|
            e.type?("uml:Class") && e.name == name
          end
        end

        # @param name [String]
        # @return [Shale::Mapper]
        def find_packaged_element_by_name(name)
          all_packaged_elements.find do |e|
            e.name == name
          end
        end

        # @param package [Shale::Mapper]
        # @return [Array<Hash>]
        # @note xpath ./packagedElement[@xmi:type="uml:Enumeration"]
        def serialize_model_enums(package)
          package.packaged_element.select { |e| e.type?("uml:Enumeration") }
            .map do |enum|
            {
              xmi_id: enum.id,
              name: enum.name,
              values: serialize_enum_owned_literal(enum),
              definition: doc_node_attribute_value(enum.id, "documentation"),
              stereotype: doc_node_attribute_value(enum.id, "stereotype"),
            }
          end
        end

        # @param model [Shale::Mapper]
        # @return [Hash]
        # @note xpath .//ownedLiteral[@xmi:type="uml:EnumerationLiteral"]
        def serialize_enum_owned_literal(enum)
          owned_literals = enum.owned_literal.select do |owned_literal|
            owned_literal.type? "uml:EnumerationLiteral"
          end

          owned_literals.map do |owned_literal|
            # xpath .//type
            uml_type_id = owned_literal&.uml_type&.idref

            {
              name: owned_literal.name,
              type: lookup_entity_name(uml_type_id) || uml_type_id,
              definition: lookup_attribute_documentation(owned_literal.id),
            }
          end
        end

        # @param model [Shale::Mapper]
        # @return [Array<Hash>]
        # @note xpath ./packagedElement[@xmi:type="uml:DataType"]
        def serialize_model_data_types(model)
          all_data_type_elements = []
          select_all_packaged_elements(all_data_type_elements, model,
                                       "uml:DataType")
          all_data_type_elements.map do |klass|
            {
              xmi_id: klass.id,
              name: klass.name,
              attributes: serialize_class_attributes(klass),
              operations: serialize_class_operations(klass),
              associations: serialize_model_associations(klass.id),
              constraints: serialize_class_constraints(klass.id),
              is_abstract: doc_node_attribute_value(klass.id, "isAbstract"),
              definition: doc_node_attribute_value(klass.id, "documentation"),
              stereotype: doc_node_attribute_value(klass.id, "stereotype"),
            }
          end
        end

        # @param node_id [String]
        # @return [Array<Hash>]
        # @note xpath %(//diagrams/diagram/model[@package="#{node['xmi:id']}"])
        def serialize_model_diagrams(node_id)
          diagrams = @xmi_root_model.extension.diagrams.diagram.select do |d|
            d.model.package == node_id
          end

          diagrams.map do |diagram|
            {
              xmi_id: diagram.id,
              name: diagram.properties.name,
              definition: diagram.properties.documentation,
            }
          end
        end

        # @param xmi_id [String]
        # @return [Array<Hash>]
        # @note xpath %(//element[@xmi:idref="#{xmi_id}"]/links/*)
        def serialize_model_associations(xmi_id)
          matched_element = @xmi_root_model.extension.elements.element
            .find { |e| e.idref == xmi_id }

          return if !matched_element ||
            !matched_element.links ||
            matched_element.links.association.empty?

          matched_element.links.association.map do |assoc|
            link_member = assoc.start == xmi_id ? "end" : "start"
            linke_owner_name = link_member == "start" ? "end" : "start"

            member_end, member_end_type, member_end_cardinality,
              member_end_attribute_name, member_end_xmi_id =
              serialize_member_type(xmi_id, assoc, link_member)

            owner_end = serialize_owned_type(xmi_id, assoc, linke_owner_name)

            if member_end && ((member_end_type != "aggregation") ||
              (member_end_type == "aggregation" && member_end_attribute_name))

              doc_node_name = (link_member == "start" ? "source" : "target")
              definition = fetch_definition_node_value(assoc.id, doc_node_name)

              {
                xmi_id: assoc.id,
                member_end: member_end,
                member_end_type: member_end_type,
                member_end_cardinality: member_end_cardinality,
                member_end_attribute_name: member_end_attribute_name,
                member_end_xmi_id: member_end_xmi_id,
                owner_end: owner_end,
                owner_end_xmi_id: xmi_id,
                definition: definition,
              }
            end
          end
        end

        # @param link_id [String]
        # @return [Shale::Mapper]
        # @note xpath %(//connector[@xmi:idref="#{link_id}"])
        def fetch_connector(link_id)
          @xmi_root_model.extension.connectors.connector.find do |con|
            con.idref == link_id
          end
        end

        # @param link_id [String]
        # @param node_name [String] source or target
        # @return [String]
        # @note xpath
        #   %(//connector[@xmi:idref="#{link_id}"]/#{node_name}/documentation)
        def fetch_definition_node_value(link_id, node_name)
          connector_node = fetch_connector(link_id)
          connector_node.send(node_name.to_sym).documentation
        end

        # @param klass [Shale::Mapper]
        # @return [Array<Hash>]
        # @note xpath .//ownedOperation
        def serialize_class_operations(klass)
          klass.owned_operation.map do |operation|
            uml_type = operation.uml_type.first
            uml_type_idref = uml_type.idref if uml_type

            if operation.association.nil?
              {
                id: operation.id,
                xmi_id: uml_type_idref,
                name: operation.name,
                definition: lookup_attribute_documentation(operation.id),
              }
            end
          end.compact
        end

        # @param klass_id [String]
        # @return [Array<Hash>]
        # @note xpath ./constraints/constraint
        def serialize_class_constraints(klass_id)
          connector_node = fetch_connector(klass_id)

          if connector_node
            # In ea-xmi-2.5.1, constraints are moved to source/target under
            # connectors
            constraints = %i[source target].map do |st|
              connector_node.send(st).constraints.constraint
            end.flatten

            constraints.map do |constraint|
              {
                name: HTMLEntities.new.decode(constraint.name),
                type: constraint.type,
                weight: constraint.weight,
                status: constraint.status,
              }
            end
          end
        end

        # @param owner_xmi_id [String]
        # @param link [Shale::Mapper]
        # @param link_member_name [String]
        # @return [String]
        def serialize_owned_type(owner_xmi_id, link, linke_owner_name)
          case link.name
          when "NoteLink"
            return
          when "Generalization"
            return generalization_association(owner_xmi_id, link)
          end

          xmi_id = link.send(linke_owner_name.to_sym)
          lookup_entity_name(xmi_id) || connector_source_name(xmi_id)

          # not necessary
          # if link.name == "Association"
          #   owned_cardinality, owned_attribute_name =
          #     fetch_assoc_connector(link.id, "source")
          # else
          #   owned_cardinality, owned_attribute_name =
          #     fetch_owned_attribute_node(xmi_id)
          # end
          # [owner_end, owned_cardinality, owned_attribute_name]
          # owner_end
        end

        # @param owner_xmi_id [String]
        # @param link [Shale::Mapper]
        # @return [Array<String, String>]
        def serialize_member_end(owner_xmi_id, link)
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

          member_end = member_end_name(xmi_id, source_or_target, link.name)
          [member_end, xmi_id]
        end

        # @param xmi_id [String]
        # @param source_or_target [Symbol]
        # @return [String]
        def member_end_name(xmi_id, source_or_target, link_name)
          connector_label = connector_labels(xmi_id, source_or_target)
          entity_name = lookup_entity_name(xmi_id)
          connector_name = connector_name_by_source_or_target(
            xmi_id, source_or_target
          )

          case link_name
          when "Aggregation"
            connector_label || entity_name || connector_name
          else
            entity_name || connector_name
          end
        end

        # @param owner_xmi_id [String]
        # @param link [Shale::Mapper]
        # @param link_member_name [String]
        # @return [Array<String, String, Hash, String, String>]
        def serialize_member_type(owner_xmi_id, link, link_member_name)
          member_end, xmi_id = serialize_member_end(owner_xmi_id, link)

          if link.name == "Association"
            connector_type = link_member_name == "start" ? "source" : "target"
            member_end_cardinality, member_end_attribute_name =
              fetch_assoc_connector(link.id, connector_type)
          else
            member_end_cardinality, member_end_attribute_name =
              fetch_owned_attribute_node(xmi_id)
          end

          [member_end, "aggregation", member_end_cardinality,
           member_end_attribute_name, xmi_id]
        end

        # @param link_id [String]
        # @param connector_type [String]
        # @return [Array<Hash, String>]
        # @note xpath %(//connector[@xmi:idref="#{link_id}"]/#{connector_type})
        def fetch_assoc_connector(link_id, connector_type)
          assoc_connector = fetch_connector(link_id).send(connector_type.to_sym)

          if assoc_connector
            assoc_connector_type = assoc_connector.type
            if assoc_connector_type&.multiplicity
              cardinality = assoc_connector_type.multiplicity.split("..")
              cardinality.unshift("1") if cardinality.length == 1
              min, max = cardinality
            end
            assoc_connector_role = assoc_connector.role
            # Does role has name attribute? Or get name from model?
            # attribute_name = assoc_connector_role.name if assoc_connector_role
            attribute_name = assoc_connector.model.name if assoc_connector_role
            cardinality = cardinality_min_max_value(min, max)
          end

          [cardinality, attribute_name]
        end

        # @param owner_xmi_id [String]
        # @param link [Shale::Mapper]
        # @return [Array<String, String, Hash, String, String>]
        # @note match return value of serialize_member_type
        def generalization_association(owner_xmi_id, link)
          member_end_type = "generalization"
          xmi_id = link.start
          source_or_target = :source

          if link.start == owner_xmi_id
            member_end_type = "inheritance"
            xmi_id = link.end
            source_or_target = :target
          end

          member_end = member_end_name(xmi_id, source_or_target, link.name)

          member_end_cardinality, _member_end_attribute_name =
            fetch_owned_attribute_node(xmi_id)

          [member_end, member_end_type, member_end_cardinality, nil, xmi_id]
        end

        # Multiple items if search type is idref.  Should search association?
        # @param xmi_id [String]
        # @return [Array<Hash, String>]
        # @note xpath
        #   %(//ownedAttribute[@association]/type[@xmi:idref="#{xmi_id}"])
        def fetch_owned_attribute_node(xmi_id)
          all_elements = all_packaged_elements

          owned_attributes = all_elements.map(&:owned_attribute).flatten
          oa = owned_attributes.find do |a|
            !!a.association && a.uml_type && a.uml_type.idref == xmi_id
          end

          if oa
            cardinality = cardinality_min_max_value(
              oa.lower_value&.value, oa.upper_value&.value
            )
            oa_name = oa.name
          end

          [cardinality, oa_name]
        end

        # @param klass_id [String]
        # @return [Shale::Mapper]
        # @note xpath %(//element[@xmi:idref="#{klass['xmi:id']}"])
        def fetch_element(klass_id)
          @xmi_root_model.extension.elements.element.find do |e|
            e.idref == klass_id
          end
        end

        # @param klass [Shale::Mapper]
        # @param with_assoc [Boolean]
        # @return [Array<Hash>]
        # @note xpath .//ownedAttribute[@xmi:type="uml:Property"]
        def serialize_class_attributes(klass, with_assoc: false)
          klass.owned_attribute.select { |attr| attr.type?("uml:Property") }
            .map do |oa|
            if with_assoc || oa.association.nil?
              attrs = build_class_attributes(oa)

              if with_assoc && oa.association
                attrs[:association] = oa.association
                attrs[:definition] = loopup_assoc_def(oa.association)
                attrs[:type_ns] = get_ns_by_type(attrs[:type])
              end

              attrs
            end
          end.compact
        end

        def loopup_assoc_def(association)
          connector = fetch_connector(association)
          connector&.documentation&.value
        end

        # @return [Array<Hash>]
        def serialize_gml_attributes
          element = find_packaged_element_by_name("_Feature")
          attrs = serialize_class_attributes(element, with_assoc: true)
          attrs.each { |attr| attr[:upper_klass] = "gml" }
        end

        # @return [Array<Hash>]
        def serialize_core_attributes
          element = find_packaged_element_by_name("_CityObject")
          attrs = serialize_class_attributes(element, with_assoc: false)
          attrs.each { |attr| attr[:upper_klass] = "core" }
        end

        # @return [Array<Hash>]
        def select_gen_attributes
          element = find_packaged_element_by_name("gen")
          gen_attr_element = find_packaged_element_by_name("_genericAttribute")

          element.packaged_element.select do |e|
            e.type?("uml:Class") &&
              e.generalization&.first&.general == gen_attr_element.id
          end
        end

        # @return [Array<Hash>]
        def serialize_gen_attributes
          klasses = select_gen_attributes

          klasses.map do |klass|
            attr = serialize_class_attributes(klass, with_assoc: false)
            attr.first[:name] = klass.name
            attr.first[:type] = "gen:#{klass.name}"
            attr.first[:upper_klass] = "gen"
            attr
          end.flatten!
        end

        # @param type [String]
        # @return [String]
        def get_ns_by_type(type)
          return unless type

          p = find_klass_packaged_element_by_name(type)
          find_upper_level_packaged_element(p.id)
        end

        # @param klass_id [String]
        # @return [Array<Hash>]
        def build_class_attributes(owned_attr) # rubocop:disable Metrics/MethodLength
          uml_type = owned_attr.uml_type
          uml_type_idref = uml_type.idref if uml_type

          {
            id: owned_attr.id,
            name: owned_attr.name,
            type: lookup_entity_name(uml_type_idref) || uml_type_idref,
            xmi_id: uml_type_idref,
            is_derived: owned_attr.is_derived,
            cardinality: cardinality_min_max_value(
              owned_attr.lower_value&.value,
              owned_attr.upper_value&.value,
            ),
            definition: lookup_attribute_documentation(owned_attr.id),
          }
        end

        # @param min [String]
        # @param max [String]
        # @return [Hash]
        def cardinality_min_max_value(min, max)
          {
            "min" => cardinality_value(min, true),
            "max" => cardinality_value(max, false),
          }
        end

        # @param value [String]
        # @param is_min [Boolean]
        # @return [String]
        def cardinality_value(value, is_min = false)
          return unless value

          is_min ? LOWER_VALUE_MAPPINGS[value.to_s] : value
        end

        # @node [Shale::Mapper]
        # @attr_name [String]
        # @return [String]
        # @note xpath %(//element[@xmi:idref="#{xmi_id}"]/properties)
        def doc_node_attribute_value(node_id, attr_name)
          doc_node = fetch_element(node_id)
          return unless doc_node

          doc_node.properties&.send(Shale::Utils.snake_case(attr_name).to_sym)
        end

        # @param xmi_id [String]
        # @return [Shale::Mapper]
        # @note xpath %(//attribute[@xmi:idref="#{xmi_id}"])
        def fetch_attribute_node(xmi_id)
          attribute_node = nil
          @xmi_root_model.extension.elements.element.each do |e|
            if e.attributes&.attribute
              e.attributes.attribute.each do |a|
                attribute_node = a if a.idref == xmi_id
              end
            end
          end
          attribute_node
        end

        # @param xmi_id [String]
        # @return [String]
        # @note xpath %(//attribute[@xmi:idref="#{xmi_id}"]/documentation)
        def lookup_attribute_documentation(xmi_id)
          attribute_node = fetch_attribute_node(xmi_id)

          return unless attribute_node&.documentation

          attribute_node&.documentation&.value
        end

        # @param xmi_id [String]
        # @return [String]
        def lookup_entity_name(xmi_id)
          model_node_name_by_xmi_id(xmi_id) if @xmi_cache.empty?
          @xmi_cache[xmi_id]
        end

        # @param xmi_id [String]
        # @param source_or_target [String]
        # @return [String]
        def connector_node_by_id(xmi_id, source_or_target)
          @xmi_root_model.extension.connectors.connector.find do |con|
            con.send(source_or_target.to_sym).idref == xmi_id
          end
        end

        # @param xmi_id [String]
        # @param source_or_target [String]
        # @return [String]
        def connector_name_by_source_or_target(xmi_id, source_or_target)
          node = connector_node_by_id(xmi_id, source_or_target)
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

        # @param xmi_id [String]
        # @return [String]
        # @note xpath %(//target[@xmi:idref="#{xmi_id}"]/model)
        def connector_target_name(xmi_id)
          connector_name_by_source_or_target(xmi_id, :target)
        end

        # @param xmi_id [String]
        # @return [String]
        # @note xpath %(//*[@xmi:id="#{xmi_id}"])
        def model_node_name_by_xmi_id(xmi_id)
          id_name_mapping = Hash.new
          map_id_name(id_name_mapping, @xmi_root_model)
          @xmi_cache = id_name_mapping
          @xmi_cache[xmi_id]
        end

        # @return [Array<Xmi::Uml::PackagedElement>]
        def all_packaged_elements
          all_elements = []
          packaged_element_roots = @xmi_root_model.model.packaged_element +
            @xmi_root_model.extension.primitive_types.packaged_element +
            @xmi_root_model.extension.profiles.profile.map(&:packaged_element)

          packaged_element_roots.flatten.each do |e|
            select_all_packaged_elements(all_elements, e, nil)
          end

          all_elements
        end

        # @param items [Array<Shale::Mapper>]
        # @param model [Shale::Mapper]
        # @param type [String] nil for any
        def select_all_items(items, model, type, method)
          iterate_tree(items, model, type, method.to_sym)
        end

        # @param all_elements [Array<Shale::Mapper>]
        # @param model [Shale::Mapper]
        # @param type [String] nil for any
        # @note xpath ./packagedElement[@xmi:type="#{type}"]
        def select_all_packaged_elements(all_elements, model, type)
          select_all_items(all_elements, model, type, :packaged_element)
          all_elements.delete_if do |e|
            !e.is_a?(Xmi::Uml::PackagedElement)
          end
        end

        # @param result [Array<Shale::Mapper>]
        # @param node [Shale::Mapper]
        # @param type [String] nil for any
        # @param children_method [String] method to determine children exist
        def iterate_tree(result, node, type, children_method)
          result << node if type.nil? || node.type == type
          return unless node.send(children_method.to_sym)

          node.send(children_method.to_sym).each do |sub_node|
            if sub_node.send(children_method.to_sym)
              iterate_tree(result, sub_node, type, children_method)
            elsif type.nil? || sub_node.type == type
              result << sub_node
            end
          end
        end

        # @param result [Hash]
        # @param node [Shale::Mapper]
        # @note set id as key and name as value into result
        #       if id and name are found
        def map_id_name(result, node)
          return if node.nil?

          if node.is_a?(Array)
            node.each do |arr_item|
              map_id_name(result, arr_item)
            end
          elsif node.class.methods.include?(:attributes)
            attrs = node.class.attributes

            if attrs.has_key?(:id) && attrs.has_key?(:name)
              result[node.id] = node.name
            end

            attrs.each_pair do |k, _v|
              map_id_name(result, node.send(k))
            end
          end
        end
      end
    end
  end
end
