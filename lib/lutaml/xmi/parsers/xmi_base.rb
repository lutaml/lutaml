require "nokogiri"
require "htmlentities"
require "lutaml/uml/has_attributes"
require "lutaml/uml/document"
require "lutaml/xmi"
require "xmi"
require "digest"

module Lutaml
  module XMI
    module Parsers
      module XMIBase
        def self.included(base)
          base.extend(ClassMethods)
        end

        module ClassMethods
          private

          # @param xml [String]
          # @return [Lutaml::Model::Serializable]
          def get_xmi_model(xml)
            Xmi::Sparx::SparxRoot.parse_xml(File.read(xml))
          end
        end

        # @param xmi_model [Lutaml::Model::Serializable]
        # @param id_name_mapping [Hash]
        # @return [Hash]
        def set_xmi_model(xmi_model, id_name_mapping = nil)
          @id_name_mapping ||= id_name_mapping || {}
          @xmi_root_model ||= xmi_model

          if @id_name_mapping.empty?
            map_id_name(@id_name_mapping, @xmi_root_model)
          end
        end

        private

        # @param xmi_model [Lutaml::Model::Serializable]
        # @param with_gen: [Boolean]
        # @param with_absolute_path: [Boolean]
        # @return [Hash]
        # @note xpath: //uml:Model[@xmi:type="uml:Model"]
        def serialize_to_hash(xmi_model,
          with_gen: false, with_absolute_path: false)
          model = xmi_model.model
          {
            name: model.name,
            packages: serialize_model_packages(
              model,
              with_gen: with_gen,
              with_absolute_path: with_absolute_path,
            ),
          }
        end

        # @param model [Lutaml::Model::Serializable]
        # @param with_gen: [Boolean]
        # @param with_absolute_path: [Boolean]
        # @param absolute_path: [String]
        # @return [Array<Hash>]
        # @note xpath ./packagedElement[@xmi:type="uml:Package"]
        def serialize_model_packages(model, # rubocop:disable Metrics/AbcSize,Metrics/MethodLength
          with_gen: false, with_absolute_path: false, absolute_path: "")
          packages = model.packaged_element.select do |e|
            e.type?("uml:Package")
          end

          if with_absolute_path
            absolute_path = "#{absolute_path}::#{model.name}"
          end

          packages.map do |package| # rubocop:disable Metrics/BlockLength
            h = {
              xmi_id: package.id,
              name: get_package_name(package),
              classes: serialize_model_classes(
                package, model,
                with_gen: with_gen,
                with_absolute_path: with_absolute_path,
                absolute_path: "#{absolute_path}::#{package.name}"
              ),
              enums: serialize_model_enums(package),
              data_types: serialize_model_data_types(package),
              diagrams: serialize_model_diagrams(
                package.id,
                with_package: with_gen,
              ),
              packages: serialize_model_packages(
                package,
                with_gen: with_gen,
                with_absolute_path: with_absolute_path,
                absolute_path: absolute_path,
              ),
              definition: doc_node_attribute_value(package.id, "documentation"),
              stereotype: doc_node_attribute_value(package.id, "stereotype"),
            }

            if with_absolute_path
              h[:absolute_path] = "#{absolute_path}::#{package.name}"
            end

            h
          end
        end

        # @param package [Lutaml::Model::Serializable]
        # @return [String]
        def get_package_name(package) # rubocop:disable Metrics/AbcSize
          return package.name unless package.name.nil?

          connector = fetch_connector(package.id)
          if connector.target&.model&.name
            return "#{connector.target.model.name} " \
                   "(#{package.type.split(':').last})"
          end

          "unnamed"
        end

        # @param package [Lutaml::Model::Serializable]
        # @param model [Lutaml::Model::Serializable]
        # @param with_gen: [Boolean]
        # @param with_absolute_path: [Boolean]
        # @return [Array<Hash>]
        # @note xpath ./packagedElement[@xmi:type="uml:Class" or
        #                               @xmi:type="uml:AssociationClass"]
        def serialize_model_classes(package, model, # rubocop:disable Metrics/MethodLength
          with_gen: false, with_absolute_path: false, absolute_path: "")
          klasses = package.packaged_element.select do |e|
            e.type?("uml:Class") || e.type?("uml:AssociationClass") ||
              e.type?("uml:Interface")
          end

          klasses.map do |klass|
            h = build_klass_hash(
              klass, model,
              with_gen: with_gen
            )

            h[:absolute_path] = absolute_path if with_absolute_path

            h
          end
        end

        # @param klass [Lutaml::Model::Serializable]
        # @param model [Lutaml::Model::Serializable]
        # @param with_gen: [Boolean]
        # @param with_absolute_path: [Boolean]
        # @return [Hash]
        def build_klass_hash(klass, model, # rubocop:disable Metrics/AbcSize,Metrics/MethodLength
          with_gen: false, with_absolute_path: false, absolute_path: "")
          klass_hash = {
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

          klass_hash[:absolute_path] = absolute_path if with_absolute_path

          if with_gen && klass.type?("uml:Class")
            klass_hash[:generalization] = serialize_generalization(klass)
          end

          klass_hash
        end

        # @param klass [Lutaml::Model::Serializable]
        # # @return [Hash]
        def serialize_generalization(klass)
          general_hash, next_general_node_id = get_top_level_general_hash(klass)
          return general_hash unless next_general_node_id

          general_hash[:general] = serialize_generalization_attributes(
            next_general_node_id,
          )

          general_hash
        end

        # @param klass [Lutaml::Model::Serializable]
        # @return [Array<Hash>]
        def get_top_level_general_hash(klass) # rubocop:disable Metrics/AbcSize
          general_hash, next_general_node_id = get_general_hash(klass.id)
          general_hash[:name] = klass.name
          general_hash[:type] = klass.type
          general_hash[:definition] = lookup_general_documentation(klass.id)
          general_hash[:stereotype] = doc_node_attribute_value(
            klass.id, "stereotype"
          )

          # update_inherited_attributes(general_hash)
          # update_gen_attributes(general_hash)

          [general_hash, next_general_node_id]
        end

        def lookup_general_documentation(klass_id)
          # lookup_attribute_documentation(klass_id) ||
          #   lookup_element_prop_documentation(klass_id)

          lookup_element_prop_documentation(klass_id)
        end

        def update_gen_attributes(general_hash)
          general_hash[:gen_attributes] = serialize_gen_attributes
        end

        def update_inherited_attributes(general_hash)
          general_hash[:gml_attributes] = serialize_gml_attributes
          general_hash[:core_attributes] = serialize_core_attributes
        end

        # @param xmi_id [String]
        # @param model [Lutaml::Model::Serializable]
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
        # @return [Lutaml::Model::Serializable]
        def get_general_node(xmi_id)
          find_packaged_element_by_id(xmi_id)
        end

        # @param general_node [Lutaml::Model::Serializable]
        # @return [Hash]
        def get_general_attributes(general_node)
          serialize_class_attributes(general_node, with_assoc: true)
        end

        # @param general_node [Lutaml::Model::Serializable]
        # @return [String]
        def get_next_general_node_id(general_node)
          general_node.generalization.first&.general
        end

        # @param general_id [String]
        # @return [Array<Hash>]
        def get_general_hash(general_id)
          general_node = get_general_node(general_id)
          return [] unless general_node

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

        # Build a cache for packaged elements by ID
        def build_packaged_element_cache
          @packaged_element_cache = all_packaged_elements.to_h { |e| [e.id, e] }
        end

        # @param id [String]
        # @return [Lutaml::Model::Serializable]
        def find_packaged_element_by_id(id)
          build_packaged_element_cache unless @packaged_element_cache
          @packaged_element_cache[id]
        end

        # @param id [String]
        # @return [Lutaml::Model::Serializable]
        def find_upper_level_packaged_element(klass_id)
          build_upper_level_cache unless @upper_level_cache
          @upper_level_cache[klass_id]
        end

        def find_subtype_of_from_owned_attribute_type(id) # rubocop:disable Metrics/AbcSize,Metrics/CyclomaticComplexity,Metrics/MethodLength,Metrics/PerceivedComplexity
          @pkg_elements_owned_attributes ||= all_packaged_elements.map do |e|
            {
              name: e.name,
              idrefs: e&.owned_attribute&.map do |oa|
                        oa&.uml_type&.idref
                      end || [],
            }
          end
          result = @pkg_elements_owned_attributes.find do |e|
            e[:idrefs].include?(id)
          end

          result[:name] if result
        end

        def find_subtype_of_from_generalization(id) # rubocop:disable Metrics/AbcSize,Metrics/CyclomaticComplexity,Metrics/MethodLength,Metrics/PerceivedComplexity
          matched_element = @xmi_root_model.extension.elements.element
            .find { |e| e.idref == id }

          return if !matched_element || !matched_element.links

          matched_generalization = nil
          matched_element.links.each do |link|
            matched_generalization = link&.generalization&.find do |g|
              g.start == id
            end
            break if matched_generalization
          end

          return if matched_generalization&.end.nil?

          lookup_entity_name(matched_generalization.end)
        end

        # Build cache once for all packaged elements
        def build_upper_level_cache
          @upper_level_cache = {}

          all_packaged_elements.each do |e|
            e.packaged_element.each do |pe|
              @upper_level_cache[pe.id] = e.name
            end
          end
        end

        # @param path [String]
        # @return [Lutaml::Model::Serializable]
        def find_klass_packaged_element(path)
          lutaml_path = Lutaml::Path.parse(path)
          if lutaml_path.segments.one?
            return find_klass_packaged_element_by_name(path)
          end

          find_klass_packaged_element_by_path(lutaml_path)
        end

        # @param path [Lutaml::Path::ElementPath]
        # @return [Lutaml::Model::Serializable]
        def find_klass_packaged_element_by_path(path)
          if path.absolute?
            iterate_packaged_element(
              @xmi_root_model.model, path.segments.map(&:name)
            )
          else
            iterate_relative_packaged_element(path.segments.map(&:name))
          end
        end

        # @param name_array [Array<String>]
        # @return [Lutaml::Model::Serializable]
        def iterate_relative_packaged_element(name_array)
          # match the first element in the name_array
          matched_elements = all_packaged_elements.select do |e|
            e.type?("uml:Package") && e.name == name_array[0]
          end

          # match the rest elements in the name_array
          result = matched_elements.map do |e|
            iterate_packaged_element(e, name_array, type: "uml:Class")
          end

          result.compact.first
        end

        # @param model [Lutaml::Model::Serializable]
        # @param name_array [Array<String>]
        # @param index: [Integer]
        # @param type: [String]
        # @return [Lutaml::Model::Serializable]
        def iterate_packaged_element(model, name_array,
          index: 1, type: "uml:Package")
          return model if index == name_array.count

          model = model.packaged_element.find do |p|
            p.name == name_array[index] && p.type?(type)
          end

          return nil if model.nil?

          index += 1
          type = index == name_array.count - 1 ? "uml:Class" : "uml:Package"
          iterate_packaged_element(model, name_array, index: index, type: type)
        end

        # @param name [String]
        # @return [Lutaml::Model::Serializable]
        def find_klass_packaged_element_by_name(name)
          all_packaged_elements.find do |e|
            e.name == name &&
              (
                e.type?("uml:Class") ||
                e.type?("uml:AssociationClass")
              )
          end
        end

        # @param name [String]
        # @return [Lutaml::Model::Serializable]
        def find_enum_packaged_element_by_name(name)
          all_packaged_elements.find do |e|
            e.name == name && e.type?("uml:Enumeration")
          end
        end

        # @param supplier_id [String]
        # @return [Lutaml::Model::Serializable]
        def select_dependencies_by_supplier(supplier_id)
          all_packaged_elements.select do |e|
            e.supplier == supplier_id &&
              e.type?("uml:Dependency")
          end
        end

        # @param supplier_id [String]
        # @return [Lutaml::Model::Serializable]
        def select_dependencies_by_client(client_id)
          all_packaged_elements.select do |e|
            e.client == client_id &&
              e.type?("uml:Dependency")
          end
        end

        # @param name [String]
        # @return [Lutaml::Model::Serializable]
        def find_packaged_element_by_name(name)
          all_packaged_elements.find do |e|
            e.name == name
          end
        end

        # @param package [Lutaml::Model::Serializable]
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

        # @param model [Lutaml::Model::Serializable]
        # @return [Hash]
        # @note xpath .//ownedLiteral[@xmi:type="uml:EnumerationLiteral"]
        def serialize_enum_owned_literal(enum) # rubocop:disable Metrics/MethodLength
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

        # @param model [Lutaml::Model::Serializable]
        # @return [Array<Hash>]
        # @note xpath ./packagedElement[@xmi:type="uml:DataType"]
        def serialize_model_data_types(model) # rubocop:disable Metrics/AbcSize,Metrics/MethodLength
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
        def serialize_model_diagrams(node_id, with_package: false) # rubocop:disable Metrics/AbcSize,Metrics/MethodLength
          diagrams = @xmi_root_model.extension.diagrams.diagram.select do |d|
            d.model.package == node_id
          end

          diagrams.map do |diagram|
            h = {
              xmi_id: diagram.id,
              name: diagram.properties.name,
              definition: diagram.properties.documentation,
            }

            if with_package
              package_id = diagram.model.package
              h[:package_id] = package_id
              h[:package_name] = find_packaged_element_by_id(package_id)&.name
            end

            h
          end
        end

        # @param xmi_id [String]
        # @return [Array<Hash>]
        # @note xpath %(//element[@xmi:idref="#{xmi_id}"]/links/*)
        def serialize_model_associations(xmi_id) # rubocop:disable Metrics/AbcSize,Metrics/CyclomaticComplexity,Metrics/MethodLength,Metrics/PerceivedComplexity
          matched_element = @xmi_root_model.extension.elements.element
            .find { |e| e.idref == xmi_id }

          return if !matched_element || !matched_element.links

          links = []
          matched_element.links.each do |link|
            links << link.association if link.association.any?
          end

          links.flatten.compact.map do |assoc|
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
        # @return [Lutaml::Model::Serializable]
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
          documentation = connector_node.send(node_name.to_sym).documentation

          if documentation.is_a?(Xmi::Sparx::SparxElementDocumentation)
            documentation&.value
          else
            documentation
          end
        end

        # @param klass [Lutaml::Model::Serializable]
        # @return [Array<Hash>]
        # @note xpath .//ownedOperation
        def serialize_class_operations(klass) # rubocop:disable Metrics/MethodLength
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
        def serialize_class_constraints(klass_id) # rubocop:disable Metrics/MethodLength
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
        # @param link [Lutaml::Model::Serializable]
        # @param link_member_name [String]
        # @return [String]
        def serialize_owned_type(owner_xmi_id, link, linke_owner_name)
          case link.name
          when "NoteLink"
            return
          when "Generalization"
            owner_end, _owner_end_type, _owner_xmi_id =
              generalization_association(owner_xmi_id, link)
            return owner_end
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
        # @param link [Lutaml::Model::Serializable]
        # @return [Array<String, String>]
        def serialize_member_end(owner_xmi_id, link) # rubocop:disable Metrics/MethodLength
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
          [member_end, "aggregation", xmi_id]
        end

        # @param xmi_id [String]
        # @param source_or_target [Symbol]
        # @return [String]
        def member_end_name(xmi_id, source_or_target, link_name) # rubocop:disable Metrics/MethodLength
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
        # @param link [Lutaml::Model::Serializable]
        # @param link_member_name [String]
        # @return [Array<String, String, Hash, String, String>]
        def serialize_member_type(owner_xmi_id, link, link_member_name) # rubocop:disable Metrics/MethodLength,Metrics/AbcSize
          member_end, member_end_type, xmi_id =
            serialize_member_end(owner_xmi_id, link)

          if link.name == "Association"
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

          member_end = member_end_name(xmi_id, source_or_target, link.name)

          # member_end_cardinality, _member_end_attribute_name =
          #   fetch_owned_attribute_node(xmi_id)
          # [member_end, member_end_type, member_end_cardinality, nil, xmi_id]
          [member_end, member_end_type, xmi_id]
        end

        # Multiple items if search type is idref.  Should search association?
        # @param xmi_id [String]
        # @return [Array<Hash, String>]
        # @note xpath
        #   %(//ownedAttribute[@association]/type[@xmi:idref="#{xmi_id}"])
        def fetch_owned_attribute_node(xmi_id) # rubocop:disable Metrics/AbcSize,Metrics/CyclomaticComplexity,Metrics/MethodLength,Metrics/PerceivedComplexity
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
        # @return [Lutaml::Model::Serializable]
        # @note xpath %(//element[@xmi:idref="#{klass['xmi:id']}"])
        def fetch_element(klass_id)
          @xmi_root_model.extension.elements.element.find do |e|
            e.idref == klass_id
          end
        end

        # @param klass [Lutaml::Model::Serializable]
        # @param with_assoc [Boolean]
        # @return [Array<Hash>]
        # @note xpath .//ownedAttribute[@xmi:type="uml:Property"]
        def serialize_class_attributes(klass, with_assoc: false) # rubocop:disable Metrics/AbcSize,Metrics/CyclomaticComplexity,Metrics/MethodLength
          klass.owned_attribute.select { |attr| attr.type?("uml:Property") }
            .map do |oa|
            if with_assoc || oa.association.nil?
              attrs = build_class_attributes(oa)

              if with_assoc && oa.association
                attrs[:association] = oa.association
                attrs[:definition] = loopup_assoc_def(oa.association)
                attrs[:type_ns] = get_ns_by_xmi_id(attrs[:xmi_id])
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
          return unless p

          find_upper_level_packaged_element(p.id)
        end

        # @param xmi_id [String]
        # @return [String]
        def get_ns_by_xmi_id(xmi_id)
          return unless xmi_id

          p = find_packaged_element_by_id(xmi_id)
          return unless p

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
            min: min,
            max: max,
          }
        end

        # @node [Lutaml::Model::Serializable]
        # @attr_name [String]
        # @return [String]
        # @note xpath %(//element[@xmi:idref="#{xmi_id}"]/properties)
        def doc_node_attribute_value(node_id, attr_name)
          doc_node = fetch_element(node_id)
          return unless doc_node

          doc_node.properties&.send(
            Lutaml::Model::Utils.snake_case(attr_name).to_sym,
          )
        end

        # @param xmi_id [String]
        # @return [Lutaml::Model::Serializable]
        # @note xpath %(//attribute[@xmi:idref="#{xmi_id}"])
        def fetch_attribute_node(xmi_id)
          @attribute_cache ||= build_attribute_cache
          @attribute_cache[xmi_id]
        end

        def build_attribute_cache
          cache = {}
          @xmi_root_model.extension.elements.element.each do |e|
            next unless e.attributes&.attribute

            e.attributes.attribute.each do |a|
              cache[a.idref] = a # Store in hash for quick lookup
            end
          end
          cache
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
        def lookup_element_prop_documentation(xmi_id)
          element_node = @xmi_root_model.extension.elements.element.find do |e|
            e.idref == xmi_id
          end

          return unless element_node&.properties

          element_node&.properties&.documentation
        end

        # @param xmi_id [String]
        # @return [String]
        def lookup_entity_name(xmi_id)
          model_node_name_by_xmi_id(xmi_id) if @id_name_mapping.empty?
          @id_name_mapping[xmi_id]
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
          @id_name_mapping = id_name_mapping
          @id_name_mapping[xmi_id]
        end

        # @return [Array<Xmi::Uml::PackagedElement>]
        def all_packaged_elements
          return @all_packaged_elements_cache if @all_packaged_elements_cache

          all_elements = []
          packaged_element_roots = @xmi_root_model.model.packaged_element +
            @xmi_root_model.extension.primitive_types.packaged_element +
            @xmi_root_model.extension.profiles.profile.map(&:packaged_element)

          packaged_element_roots.flatten.each do |e|
            select_all_packaged_elements(all_elements, e, nil)
          end

          @all_packaged_elements_cache = all_elements
          all_elements
        end

        # @param items [Array<Lutaml::Model::Serializable>]
        # @param model [Lutaml::Model::Serializable]
        # @param type [String] nil for any
        def select_all_items(items, model, type, method)
          iterate_tree(items, model, type, method.to_sym)
        end

        # @param all_elements [Array<Lutaml::Model::Serializable>]
        # @param model [Lutaml::Model::Serializable]
        # @param type [String] nil for any
        # @note xpath ./packagedElement[@xmi:type="#{type}"]
        def select_all_packaged_elements(all_elements, model, type)
          select_all_items(all_elements, model, type, :packaged_element)
          all_elements.delete_if do |e|
            !e.is_a?(Xmi::Uml::PackagedElement)
          end
        end

        # @param result [Array<Lutaml::Model::Serializable>]
        # @param node [Lutaml::Model::Serializable]
        # @param type [String] nil for any
        # @param children_method [String] method to determine children exist
        def iterate_tree(result, node, type, children_method) # rubocop:disable Metrics/AbcSize,Metrics/CyclomaticComplexity,Metrics/PerceivedComplexity
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
        # @param node [Lutaml::Model::Serializable]
        # @note set id as key and name as value into result
        #       if id and name are found
        def map_id_name(result, node) # rubocop:disable Metrics/AbcSize,Metrics/CyclomaticComplexity,Metrics/MethodLength,Metrics/PerceivedComplexity
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
