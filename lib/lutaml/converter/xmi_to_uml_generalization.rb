# frozen_string_literal: true

module Lutaml
  module Converter
    module XmiToUml
      # Generalization-related conversion methods for XMI → UML
      #
      # These methods handle the recursive generalization hierarchy:
      # creating UML generalization objects, walking the chain of
      # parent classes, and collecting inherited properties.

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
        general_node = find_packaged_element_by_id(general_id)
        return [] unless general_node

        general_node_attrs = get_uml_general_attributes(general_node)
        general_upper_klass = find_upper_level_packaged_element(general_id)
        next_general_node_id = get_next_general_node_id(general_node)

        uml_general = build_uml_general_node(
          general_id, general_node, general_node_attrs,
          general_upper_klass, next_general_node_id
        )

        assign_general_properties(uml_general)

        [uml_general, next_general_node_id]
      end

      def build_uml_general_node(general_id, general_node, attrs, upper_klass, next_id)
        gen = ::Lutaml::Uml::Generalization.new
        assign_general_basic_props(gen, general_id, general_node, attrs, upper_klass)
        assign_stereotype(gen, general_id)
        assign_parent_generalization(gen, general_node, next_id)
        gen
      end

      def assign_general_basic_props(gen, general_id, general_node, attrs, upper_klass)
        gen.general_id = general_id
        gen.general_name = general_node.name
        gen.general_attributes = attrs
        gen.general_upper_klass = upper_klass&.name
        gen.name = general_node.name
        gen.type = general_node.type
        gen.definition = lookup_element_prop_documentation(general_id)
      end

      def assign_stereotype(gen, general_id)
        gen_st = doc_node_attribute_value(general_id, "stereotype")
        gen.stereotype = [gen_st] if gen_st
      end

      def assign_parent_generalization(gen, general_node, next_id)
        return unless next_id

        gen.general = set_uml_generalization(next_id)
        gen.has_general = true
        gen.general_id = general_node.id
        gen.general_name = general_node.name
      end

      def assign_general_properties(uml_general)
        uml_general.attributes = create_uml_attributes(uml_general)
        uml_general.owned_props = uml_general.attributes.select do |attr|
          attr.association.nil?
        end
        uml_general.assoc_props = uml_general.attributes.select(&:association)
      end

      def get_uml_general_attributes(general_node) # rubocop:disable Metrics/AbcSize,Metrics/MethodLength
        attrs = create_uml_class_attributes(general_node)

        attrs.sort_by { |a| [a.name.to_s, a.id] }.map do |attr|
          ::Lutaml::Uml::GeneralAttribute.new.tap do |gen_attr|
            gen_attr.id = attr.id
            gen_attr.name = attr.name
            gen_attr.type = attr.type
            gen_attr.xmi_id = attr.xmi_id
            gen_attr.is_derived = !!attr.is_derived
            gen_attr.cardinality = attr.cardinality
            gen_attr.definition = attr.definition&.strip
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

      def create_uml_assoc_generalizations(klass) # rubocop:disable Metrics/AbcSize
        return [] if klass.generalization.nil? || klass.generalization.empty?

        klass.generalization.map do |gen|
          ::Lutaml::Uml::AssociationGeneralization.new.tap do |assoc_gen|
            assoc_gen.id = gen.id
            assoc_gen.type = gen.type
            assoc_gen.general = gen.general
          end
        end
      end
    end
  end
end
