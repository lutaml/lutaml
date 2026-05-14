# frozen_string_literal: true

module Lutaml
  module Qea
    module Factory
      class GeneralizationBuilder < BaseTransformer
        def load_generalization(object_id, visited = Set.new, is_leaf = true) # rubocop:disable Style/OptionalBooleanParameter
          return nil if object_id.nil?
          return nil if circular_inheritance?(object_id, visited)

          visited = visited.dup.add(object_id)

          current_obj = find_object_by_id(object_id)
          return nil unless current_obj

          generalization = build_generalization(object_id, current_obj)
          return nil unless generalization

          populate_generalization_attrs(generalization, object_id)
          populate_parent_generalization(generalization,
                                         ea_connector_for(object_id), visited)

          collect_inherited_properties(generalization) if is_leaf && generalization.has_general

          generalization
        end

        def circular_inheritance?(object_id, visited)
          return false unless visited.include?(object_id)

          warn "Circular inheritance detected for object_id #{object_id}, " \
               "stopping recursion"
          true
        end

        def load_association_generalizations(object_id)
          return [] if object_id.nil?

          gen_connectors = database.connectors_for_object(object_id)
            .select { |c| c.generalization? && c.start_object_id == object_id }

          gen_connectors.filter_map do |ea_connector|
            build_assoc_generalization(ea_connector)
          end
        end

        def convert_to_general_attributes(attributes)
          attributes.map { |attr| to_general_attribute(attr) }
        end

        def convert_to_top_element_attributes(attributes)
          attributes.map { |attr| to_top_element_attribute(attr) }
        end

        def to_general_attribute(attr)
          base = base_attr_hash(attr)
          Lutaml::Uml::GeneralAttribute.new.tap do |gen_attr|
            base.each { |k, v| gen_attr.public_send(:"#{k}=", v) }
            gen_attr.is_derived = !!attr.is_derived
            gen_attr.has_association = !!attr.association
          end
        end

        def to_top_element_attribute(attr)
          base = base_attr_hash(attr)
          Lutaml::Uml::TopElementAttribute.new.tap do |top_attr|
            base.each { |k, v| top_attr.public_send(:"#{k}=", v) }
            top_attr.is_derived = !!attr.is_derived
          end
        end

        def base_attr_hash(attr)
          {
            id: attr.id,
            name: attr.name,
            type: attr.type,
            xmi_id: attr.xmi_id,
            cardinality: attr.cardinality,
            definition: attr.definition&.strip,
            association: attr.association,
            type_ns: attr.type_ns,
          }
        end

        private

        def tag_ancestor_attributes(gen, level)
          [gen.general_attributes, gen.attributes].each do |attr_list|
            attr_list&.each do |attr|
              attr.upper_klass = gen.general_upper_klass
              attr.level = level
            end
          end
        end

        def collect_ancestor_attrs(gen, level, inherited_props,
                                   inherited_assoc_props)
          gen.attributes.reverse_each do |attr|
            inherited_attr = attr.dup
            inherited_attr.upper_klass = gen.general_upper_klass
            inherited_attr.gen_name = gen.general_name
            inherited_attr.level = level

            if attr.has_association
              inherited_assoc_props << inherited_attr
            else
              inherited_props << inherited_attr
            end
          end
        end

        def build_assoc_generalization(ea_connector)
          parent_obj = find_object_by_id(ea_connector.end_object_id)
          return nil unless parent_obj

          Lutaml::Uml::AssociationGeneralization.new.tap do |ag|
            ag.id = normalize_guid_to_xmi_format(ea_connector.ea_guid, "EAID")
            ag.type = "uml:Generalization"
            ag.general = normalize_guid_to_xmi_format(parent_obj.ea_guid,
                                                      "EAID")
          end
        end

        def resolve_name_ns(type_ns, upper_klass)
          ns = case type_ns
               when "core", "gml"
                 upper_klass
               else
                 type_ns
               end
          ns || upper_klass
        end

        def build_generalization(object_id, current_obj)
          ea_connector = ea_connector_for(object_id)
          gen_transformer = GeneralizationTransformer.new(database)
          if ea_connector.nil?
            gen_transformer.transform(nil, current_obj)
          else
            gen_transformer.transform(ea_connector, current_obj)
          end
        end

        def ea_connector_for(object_id)
          database.connectors_for_object(object_id)
            .find { |c| c.generalization? && c.start_object_id == object_id }
        end

        def populate_generalization_attrs(generalization, object_id)
          general_attrs = build_general_attrs(object_id)
          apply_namespace_to_attrs(general_attrs, generalization)

          generalization.general_attributes = general_attrs
            .sort_by { |a| [a.name.to_s, a.id] }

          generalization.attributes = transform_general_attributes(
            generalization,
          )

          generalization.owned_props = generalization.attributes
            .reject(&:has_association)
          generalization.assoc_props = generalization.attributes
            .select(&:has_association)
        end

        def build_general_attrs(object_id)
          current_attrs = load_attributes(object_id)
          current_assoc_attrs = AssociationBuilder.new(database)
            .load_association_attributes(object_id)
          convert_to_general_attributes(current_attrs + current_assoc_attrs)
        end

        def apply_namespace_to_attrs(general_attrs, generalization)
          upper_klass = generalization.general_upper_klass
          general_attrs.each do |attr|
            attr.gen_name = generalization.general_name
            attr.name_ns = resolve_name_ns(attr.type_ns, upper_klass)
          end
        end

        def populate_parent_generalization(generalization, ea_connector,
visited)
          parent_object_id = ea_connector&.end_object_id
          return unless parent_object_id

          parent_gen = load_generalization(parent_object_id, visited, false)
          return unless parent_gen

          generalization.general = parent_gen
          generalization.has_general = true
        end

        def load_attributes(object_id)
          return [] if object_id.nil?

          ea_attributes = database.attributes_for_object(object_id)
            .sort_by { |a| a.pos || 0 }

          AttributeTransformer.new(database).transform_collection(ea_attributes)
        end

        def transform_general_attributes(generalization)
          upper_klass = generalization.general_upper_klass
          gen_name = generalization.general_name

          generalization.general_attributes.map do |attr|
            transformed = attr.dup
            transformed.name_ns = resolve_name_ns(attr.type_ns, upper_klass)
            transformed.gen_name = gen_name
            transformed.name = "" if transformed.name.nil?
            transformed
          end
        end

        def collect_inherited_properties(generalization)
          inherited_props = []
          inherited_assoc_props = []
          level = 0

          current_gen = generalization.general
          while current_gen
            tag_ancestor_attributes(current_gen, level)
            collect_ancestor_attrs(current_gen, level, inherited_props,
                                   inherited_assoc_props)

            level += 1
            current_gen = current_gen.general
          end

          generalization.inherited_props = inherited_props.reverse
          generalization.inherited_assoc_props = inherited_assoc_props.reverse
        end
      end
    end
  end
end
