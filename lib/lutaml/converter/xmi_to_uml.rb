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
        pkg.stereotype = doc_node_attribute_value(package.id, "stereotype")

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
          k.stereotype = doc_node_attribute_value(klass.id, "stereotype")

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
            en.stereotype = doc_node_attribute_value(enum.id, "stereotype")
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
            data_type.stereotype = doc_node_attribute_value(
              dt.id, "stereotype"
            )

            data_type.attributes = create_uml_class_attributes(dt)
            data_type.operations = create_uml_operations(dt)
            data_type.associations = create_uml_associations(dt.id)
            data_type.constraints = create_uml_constraints(dt.id)
          end
        end
      end

      def create_uml_diagrams(node_id) # rubocop:disable Metrics/AbcSize,Metrics/MethodLength,Metrics/CyclomaticComplexity,Metrics/PerceivedComplexity
        return [] if @xmi_root_model.extension&.diagrams&.diagram.nil?

        diagrams = @xmi_root_model.extension.diagrams.diagram.select do |d|
          d.model.package == node_id
        end

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

      def create_uml_class_attributes(klass) # rubocop:disable Metrics/AbcSize,Metrics/CyclomaticComplexity,Metrics/MethodLength
        return [] if klass.owned_attribute.nil?

        owned_attributes = klass.owned_attribute.select do |attr|
          attr.type?("uml:Property")
        end

        owned_attributes.map do |oa|
          create_uml_attribute(oa)
        end.compact
      end

      def create_uml_attribute(owned_attr) # rubocop:disable Metrics/AbcSize,Metrics/MethodLength
        uml_type = owned_attr.uml_type
        uml_type_idref = uml_type.idref if uml_type

        ::Lutaml::Uml::TopElementAttribute.new.tap do |attr|
          attr.id = owned_attr.id
          attr.name = owned_attr.name
          attr.type = lookup_entity_name(uml_type_idref) || uml_type_idref
          attr.xmi_id = uml_type_idref
          attr.is_derived = owned_attr.is_derived
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
        ::Lutaml::Uml::Cardinality.new.tap do |cardinality|
          cardinality.min = hash[:min]
          cardinality.max = hash[:max]
        end
      end

      def create_uml_attributes(uml_general_obj) # rubocop:disable Metrics/AbcSize,Metrics/MethodLength
        upper_klass = uml_general_obj.general_upper_klass
        gen_attrs = uml_general_obj.general_attributes
        gen_name = uml_general_obj.general_name

        gen_attrs&.each do |i|
          name_ns = case i.type_ns
                    when "core", "gml"
                      upper_klass
                    else
                      i.type_ns
                    end
          name_ns = upper_klass if name_ns.nil?

          i.name_ns = name_ns
          i.gen_name = gen_name
          i.name = "" if i.name.nil?
        end

        gen_attrs
      end

      def create_uml_generalization(klass) # rubocop:disable Metrics/AbcSize,Metrics/MethodLength,Metrics/CyclomaticComplexity,Metrics/PerceivedComplexity
        uml_general_obj, next_general_node_id = get_uml_general(klass.id)
        return uml_general_obj unless next_general_node_id

        if uml_general_obj.general
          inherited_props = []
          inherited_assoc_props = []
          level = 0

          loop_general_item(
            uml_general_obj.general,
            level,
            inherited_props,
            inherited_assoc_props,
          )
          uml_general_obj.inherited_props = inherited_props.reverse
          uml_general_obj.inherited_assoc_props = inherited_assoc_props.reverse
        end

        uml_general_obj
      end

      def get_uml_general(general_id) # rubocop:disable Metrics/AbcSize,Metrics/MethodLength
        general_node = get_general_node(general_id)
        return [] unless general_node

        general_node_attrs = get_uml_general_attributes(general_node)
        general_upper_klass = find_upper_level_packaged_element(general_id)
        next_general_node_id = get_next_general_node_id(general_node)

        uml_general = ::Lutaml::Uml::Generalization.new.tap do |gen|
          gen.general_id = general_id
          gen.general_name = general_node.name
          gen.general_attributes = general_node_attrs
          gen.general_upper_klass = general_upper_klass
          gen.name = general_node.name
          gen.type = general_node.type
          gen.definition = lookup_general_documentation(general_id)
          gen.stereotype = doc_node_attribute_value(general_id, "stereotype")

          if next_general_node_id
            gen.general = set_uml_generalization(
              next_general_node_id,
            )
            gen.has_general = true
            gen.general_id = general_node.id
            gen.general_name = general_node.name
          end
        end

        uml_general.attributes = create_uml_attributes(uml_general)
        uml_general.owned_props = uml_general.attributes.select do |attr|
          attr.association.nil?
        end
        uml_general.assoc_props = uml_general
          .attributes.select(&:association)

        [uml_general, next_general_node_id]
      end

      def get_uml_general_attributes(general_node) # rubocop:disable Metrics/AbcSize,Metrics/MethodLength
        attrs = create_uml_class_attributes(general_node)

        attrs.map do |attr|
          ::Lutaml::Uml::GeneralAttribute.new.tap do |gen_attr|
            gen_attr.id = attr.id
            gen_attr.name = attr.name
            gen_attr.type = attr.type
            gen_attr.xmi_id = attr.xmi_id
            gen_attr.is_derived = !!attr.is_derived
            gen_attr.cardinality = attr.cardinality
            gen_attr.definition = attr.definition
            gen_attr.association = attr.association
            gen_attr.has_association = !!attr.association
            gen_attr.type_ns = attr.type_ns
          end
        end
      end

      def set_uml_generalization(general_id)
        uml_general_obj, next_general_node_id = get_uml_general(general_id)

        if next_general_node_id
          uml_general_obj.general = set_uml_generalization(
            next_general_node_id,
          )
          uml_general_obj.has_general = true
        end

        uml_general_obj
      end

      def loop_general_item( # rubocop:disable Metrics/MethodLength,Metrics/AbcSize,Metrics/PerceivedComplexity,Metrics/CyclomaticComplexity
        general_item, level, inherited_props, inherited_assoc_props
      )
        gen_upper_klass = general_item.general_upper_klass
        gen_name = general_item.general_name

        # reverse the order to show super class first
        general_item.attributes.reverse_each do |attr|
          attr.upper_klass = gen_upper_klass
          attr.gen_name = gen_name
          attr.level = level

          if attr.association
            inherited_assoc_props << attr
          else
            inherited_props << attr
          end
        end

        if general_item&.has_general && general_item.general
          level += 1
          loop_general_item(
            general_item.general, level, inherited_props, inherited_assoc_props
          )
        end
      end

      def create_uml_assoc_generalizations(klass)
        return [] if klass.generalization.nil? || klass.generalization.empty?

        klass.generalization.map do |gen|
          assoc_gen = ::Lutaml::Uml::AssociationGeneralization.new
          assoc_gen.id = gen.id
          assoc_gen.type = gen.type
          assoc_gen.general = gen.general
        end
      end

      def create_uml_associations(xmi_id) # rubocop:disable Metrics/AbcSize,Metrics/CyclomaticComplexity,Metrics/MethodLength,Metrics/PerceivedComplexity
        matched_element = @xmi_root_model.extension.elements.element
          .find { |e| e.idref == xmi_id }

        return if !matched_element || !matched_element.links

        links = []
        matched_element.links.each do |link|
          links << link.association if link.association.any?
        end

        links.flatten.compact.map do |assoc| # rubocop:disable Metrics/BlockLength
          link_member = assoc.start == xmi_id ? "end" : "start"
          link_owner = link_member == "start" ? "end" : "start"

          member_end, member_end_type, member_end_cardinality,
            member_end_attribute_name, member_end_xmi_id =
            serialize_member_type(xmi_id, assoc, link_member)

          owner_end = serialize_owned_type(xmi_id, assoc, link_owner)
          doc_node = link_member == "start" ? "source" : "target"
          definition = fetch_definition_node_value(assoc.id, doc_node)

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
              association.definition = definition
            end
          end
        end.compact
      end

      def create_uml_operations(klass) # rubocop:disable Metrics/MethodLength,Metrics/AbcSize
        return [] if klass.owned_operation.nil?

        klass.owned_operation.map do |operation|
          uml_type = operation.uml_type.first
          uml_type_idref = uml_type.idref if uml_type

          if operation.association.nil?
            ::Lutaml::Uml::Operation.new.tap do |op|
              op.id = operation.id
              op.xmi_id = uml_type_idref
              op.name = operation.name
              op.definition = lookup_attribute_documentation(operation.id)
            end
          end
        end.compact
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
