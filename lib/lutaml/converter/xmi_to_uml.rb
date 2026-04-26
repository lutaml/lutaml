# frozen_string_literal: true

require_relative "xmi_to_uml_generalization"

module Lutaml
  module Converter
    module XmiToUml
      def create_uml_document(xmi_model)
        ::Lutaml::Uml::Document.new.tap do |doc|
          doc.name = xmi_model.model.name
          doc.packages = create_uml_packages(xmi_model.model)
        end
      end

      def create_uml_packages(model)
        return [] if model.packaged_element.nil?

        packages = model.packaged_element.select do |e|
          e.type?("uml:Package")
        end

        packages.map do |package|
          create_uml_package(package)
        end
      end

      def create_uml_package(package) # rubocop:disable Metrics/AbcSize,Metrics/MethodLength
        pkg = ::Lutaml::Uml::Package.new
        pkg.xmi_id = package.id
        pkg.name = get_package_name(package)
        pkg.definition = doc_node_attribute_value(package.id, "documentation")
        st = doc_node_attribute_value(package.id, "stereotype")
        pkg.stereotype = [st] if st

        pkg.packages = create_uml_packages(package)
        pkg.classes = create_uml_classes(package)
        pkg.enums = create_uml_enums(package)
        pkg.data_types = create_uml_data_types(package)
        pkg.diagrams = create_uml_diagrams(package.id)

        pkg
      end

      def create_uml_classes(package)
        return [] if package.packaged_element.nil?

        klasses = package.packaged_element.select do |e|
          e.type?("uml:Class") || e.type?("uml:AssociationClass") ||
            e.type?("uml:Interface")
        end

        klasses.map do |klass|
          create_uml_class(klass)
        end
      end

      def create_uml_class(klass) # rubocop:disable Metrics/MethodLength,Metrics/AbcSize,Metrics/CyclomaticComplexity,Metrics/PerceivedComplexity
        ::Lutaml::Uml::Class.new.tap do |k| # rubocop:disable Metrics/BlockLength
          k.xmi_id = klass.id
          k.name = klass.name
          k.type = klass.type.split(":").last
          k.is_abstract = doc_node_attribute_value(klass.id, "isAbstract")
          k.definition = doc_node_attribute_value(klass.id, "documentation")
          k_st = doc_node_attribute_value(klass.id, "stereotype")
          k.stereotype = [k_st] if k_st

          k.attributes = create_uml_class_attributes(klass)
          k.associations = create_uml_associations(klass.id)
          k.operations = create_uml_operations(klass)
          k.constraints = create_uml_constraints(klass.id)
          k.association_generalization = create_uml_assoc_generalizations(klass)

          if klass.type?("uml:Class")
            k.generalization = create_uml_generalization(klass)
          end
        end
      end

      def create_uml_enums(package) # rubocop:disable Metrics/MethodLength,Metrics/AbcSize
        return [] if package.packaged_element.nil?

        enums = package.packaged_element.select do |e|
          e.type?("uml:Enumeration")
        end

        enums.map do |enum|
          ::Lutaml::Uml::Enum.new.tap do |en|
            en.xmi_id = enum.id
            en.name = enum.name
            en.values = create_uml_values(enum)
            en.definition = doc_node_attribute_value(enum.id, "documentation")
            en_st = doc_node_attribute_value(enum.id, "stereotype")
            en.stereotype = [en_st] if en_st
          end
        end
      end

      def create_uml_data_types(package) # rubocop:disable Metrics/AbcSize,Metrics/MethodLength
        return [] if package.packaged_element.nil?

        data_types = package.packaged_element.select do |e|
          e.type?("uml:DataType")
        end

        data_types.map do |dt|
          ::Lutaml::Uml::DataType.new.tap do |data_type|
            data_type.xmi_id = dt.id
            data_type.name = dt.name
            data_type.is_abstract = doc_node_attribute_value(
              dt.id, "isAbstract"
            )
            data_type.definition = doc_node_attribute_value(
              dt.id, "documentation"
            )
            dt_st = doc_node_attribute_value(
              dt.id, "stereotype"
            )
            data_type.stereotype = [dt_st] if dt_st

            data_type.attributes = create_uml_class_attributes(dt)
            data_type.operations = create_uml_operations(dt)
            data_type.associations = create_uml_associations(dt.id)
            data_type.constraints = create_uml_constraints(dt.id)
          end
        end
      end

      def create_uml_diagrams(node_id) # rubocop:disable Metrics/AbcSize,Metrics/MethodLength,Metrics/CyclomaticComplexity,Metrics/PerceivedComplexity
        return [] if @xmi_root_model.extension&.diagrams&.diagram.nil?

        diagrams = diagram_lookup[node_id]

        diagrams.map do |diagram|
          ::Lutaml::Uml::Diagram.new.tap do |dia|
            dia.xmi_id = diagram.id
            dia.name = diagram&.properties&.name
            dia.definition = diagram&.properties&.documentation

            package_id = diagram&.model&.package
            if package_id
              dia.package_id = package_id
              dia.package_name = find_packaged_element_by_id(package_id)&.name
            end
          end
        end
      end

      # Lazy-built hash index for O(1) diagram lookups by package
      # @return [Hash] Mapping of package_id => [diagrams]
      def diagram_lookup
        @diagram_lookup ||= begin
          idx = Hash.new { |h, k| h[k] = [] }
          diagrams = @xmi_root_model.extension&.diagrams&.diagram || []
          diagrams.each { |d| idx[d.model.package] << d if d.model&.package }
          idx
        end
      end

      def create_uml_class_attributes(klass) # rubocop:disable Metrics/AbcSize,Metrics/CyclomaticComplexity,Metrics/MethodLength
        return [] if klass.owned_attribute.nil?

        all_props = klass.owned_attribute.select do |attr|
          attr.type?("uml:Property")
        end

        all_props.filter_map do |oa|
          create_uml_attribute(oa)
        end
      end

      def create_uml_attribute(owned_attr) # rubocop:disable Metrics/AbcSize,Metrics/MethodLength
        uml_type = owned_attr.uml_type
        uml_type_idref = uml_type.idref if uml_type

        ::Lutaml::Uml::TopElementAttribute.new.tap do |attr|
          attr.id = owned_attr.id
          attr.name = owned_attr.name
          attr.type = lookup_entity_name(uml_type_idref) || uml_type_idref
          attr.xmi_id = uml_type_idref
          attr.is_derived = !!owned_attr.is_derived
          attr.cardinality = ::Lutaml::Uml::Cardinality.new.tap do |car|
            car.min = owned_attr.lower_value&.value
            car.max = owned_attr.upper_value&.value
          end
          attr.definition = lookup_attribute_documentation(owned_attr.id)

          if owned_attr.association
            attr.association = owned_attr.association
            attr.definition = loopup_assoc_def(owned_attr.association)
            attr.type_ns = get_ns_by_xmi_id(attr.xmi_id)
          end
        end
      end

      def create_uml_cardinality(hash)
        return nil unless hash

        ::Lutaml::Uml::Cardinality.new.tap do |cardinality|
          cardinality.min = hash[:min]
          cardinality.max = hash[:max]
        end
      end

      def create_uml_associations(xmi_id) # rubocop:disable Metrics/AbcSize,Metrics/CyclomaticComplexity,Metrics/MethodLength,Metrics/PerceivedComplexity
        matched_element = xmi_index&.find_element(xmi_id)

        return if !matched_element || !matched_element.links

        links = []
        matched_element.links.each do |link|
          links << link.association if link.association.any?
        end

        links.flatten.compact.filter_map do |assoc| # rubocop:disable Metrics/BlockLength
          link_member = assoc.start == xmi_id ? "end" : "start"
          link_owner = link_member == "start" ? "end" : "start"

          member_end, member_end_type, member_end_cardinality,
            member_end_attribute_name, member_end_xmi_id =
            serialize_member_type(xmi_id, assoc, link_member)

          owner_end = serialize_owned_type(xmi_id, assoc, link_owner)
          doc_node = link_member == "start" ? "source" : "target"
          definition = fetch_definition_node_value(assoc.id, doc_node)

          # Get owner_end_attribute_name from the ownedAttribute that
          # references this association
          owner_end_attribute_name = find_owner_attribute_name(xmi_id, assoc.id)

          if member_end &&
              (
                (member_end_type != "aggregation") ||
                (member_end_type == "aggregation" && member_end_attribute_name)
              )

            ::Lutaml::Uml::Association.new.tap do |association|
              association.xmi_id = assoc.id
              association.member_end = member_end
              association.member_end_type = member_end_type
              association.member_end_cardinality = create_uml_cardinality(
                member_end_cardinality,
              )
              association.member_end_attribute_name = member_end_attribute_name
              association.member_end_xmi_id = member_end_xmi_id
              association.owner_end = owner_end
              association.owner_end_xmi_id = xmi_id
              association.owner_end_attribute_name = owner_end_attribute_name
              association.definition = definition
            end
          end
        end
      end

      # Find the ownedAttribute name that references this association
      # This gives us the role name from the owner's perspective
      def find_owner_attribute_name(owner_xmi_id, assoc_id)
        owner_node = find_packaged_element_by_id(owner_xmi_id)
        return nil unless owner_node&.owned_attribute

        owned_attr = owner_node.owned_attribute.find do |oa|
          oa.association == assoc_id
        end

        owned_attr&.name
      end

      def create_uml_operations(klass) # rubocop:disable Metrics/MethodLength,Metrics/AbcSize
        return [] if klass.owned_operation.nil?

        klass.owned_operation.filter_map do |operation|
          uml_type = operation.uml_type.first
          uml_type_idref = uml_type.idref if uml_type

          if !operation.respond_to?(:association) || operation.association.nil?
            ::Lutaml::Uml::Operation.new.tap do |op|
              op.id = operation.id
              op.xmi_id = uml_type_idref
              op.name = operation.name
              op.definition = lookup_attribute_documentation(operation.id)
            end
          end
        end
      end

      def create_uml_constraints(klass_id) # rubocop:disable Metrics/MethodLength,Metrics/AbcSize
        connector_node = fetch_connector(klass_id)
        return [] if connector_node.nil?

        # In ea-xmi-2.5.1, constraints are moved to source/target under
        # connectors
        constraints = %i[source target].map do |st|
          connector_node.send(st).constraints.constraint
        end.flatten

        constraints.map do |constraint|
          ::Lutaml::Uml::Constraint.new.tap do |con|
            con.name = HTMLEntities.new.decode(constraint.name)
            con.type = constraint.type
            con.weight = constraint.weight
            con.status = constraint.status
          end
        end
      end

      def create_uml_values(enum) # rubocop:disable Metrics/MethodLength,Metrics/CyclomaticComplexity,Metrics/AbcSize
        return [] if enum.owned_literal.nil?

        owned_literals = enum.owned_literal.select do |owned_literal|
          owned_literal.type?("uml:EnumerationLiteral")
        end

        owned_literals.map do |owned_literal|
          uml_type_id = owned_literal&.uml_type&.idref

          ::Lutaml::Uml::Value.new.tap do |value|
            value.name = owned_literal.name
            value.type = lookup_entity_name(uml_type_id) || uml_type_id
            value.definition = lookup_attribute_documentation(owned_literal.id)
          end
        end
      end
    end
  end
end
