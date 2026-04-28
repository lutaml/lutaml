# frozen_string_literal: true

require "set"
require_relative "base_transformer"
require_relative "attribute_transformer"
require_relative "generalization_transformer"
require_relative "association_builder"

module Lutaml
  module Qea
    module Factory
      class GeneralizationBuilder < BaseTransformer
        def load_generalization(object_id, visited = Set.new, is_leaf = true) # rubocop:disable Metrics/AbcSize,Metrics/CyclomaticComplexity,Metrics/MethodLength,Metrics/PerceivedComplexity,Style/OptionalBooleanParameter
          return nil if object_id.nil?

          if visited.include?(object_id)
            warn "Circular inheritance detected for object_id #{object_id}, " \
                 "stopping recursion"
            return nil
          end

          visited = visited.dup.add(object_id)

          current_obj = find_object_by_id(object_id)
          return nil unless current_obj

          ea_connector = database.connectors_for_object(object_id)
            .find { |c| c.generalization? && c.start_object_id == object_id }

          gen_transformer = GeneralizationTransformer.new(database)
          generalization = if ea_connector.nil?
                             gen_transformer.transform(nil, current_obj)
                           else
                             gen_transformer.transform(ea_connector, current_obj)
                           end
          return nil unless generalization

          current_attrs = load_attributes(object_id)
          current_assoc_attrs = AssociationBuilder.new(database)
            .load_association_attributes(object_id)
          general_attrs = convert_to_general_attributes(
            current_attrs + current_assoc_attrs,
          )

          upper_klass = generalization.general_upper_klass
          gen_name = generalization.general_name
          general_attrs.each do |attr|
            attr.gen_name = gen_name
            name_ns = case attr.type_ns
                      when "core", "gml"
                        upper_klass
                      else
                        attr.type_ns
                      end
            attr.name_ns = name_ns || upper_klass
          end

          generalization.general_attributes = general_attrs
            .sort_by { |a| [a.name.to_s, a.id] }

          generalization.attributes = transform_general_attributes(
            generalization,
          )

          generalization.owned_props = generalization.attributes
            .reject(&:has_association)
          generalization.assoc_props = generalization.attributes
            .select(&:has_association)

          parent_object_id = ea_connector&.end_object_id
          if parent_object_id
            parent_gen = load_generalization(parent_object_id, visited, false)
            if parent_gen
              generalization.general = parent_gen
              generalization.has_general = true
            end
          end

          if is_leaf && generalization.has_general
            collect_inherited_properties(generalization)
          end

          generalization
        end

        def load_association_generalizations(object_id)
          return [] if object_id.nil?

          gen_connectors = database.connectors_for_object(object_id)
            .select { |c| c.generalization? && c.start_object_id == object_id }

          gen_connectors.filter_map do |ea_connector|
            guid = ea_connector.ea_guid
            parent_object_id = ea_connector.end_object_id

            parent_obj = find_object_by_id(parent_object_id)
            next unless parent_obj

            Lutaml::Uml::AssociationGeneralization.new.tap do |ag|
              ag.id = normalize_guid_to_xmi_format(guid, "EAID")
              ag.type = "uml:Generalization"
              ag.general = normalize_guid_to_xmi_format(parent_obj.ea_guid,
                                                        "EAID")
            end
          end
        end

        def convert_to_general_attributes(attributes)
          attributes.map do |attr|
            Lutaml::Uml::GeneralAttribute.new.tap do |gen_attr|
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

        def convert_to_top_element_attributes(attributes)
          attributes.map do |attr|
            Lutaml::Uml::TopElementAttribute.new.tap do |top_attr|
              top_attr.id = attr.id
              top_attr.name = attr.name
              top_attr.type = attr.type
              top_attr.xmi_id = attr.xmi_id
              top_attr.cardinality = attr.cardinality
              top_attr.definition = attr.definition&.strip
              top_attr.association = attr.association
              top_attr.type_ns = attr.type_ns
              top_attr.is_derived = !!attr.is_derived
            end
          end
        end

        private

        def load_attributes(object_id)
          return [] if object_id.nil?

          ea_attributes = database.attributes_for_object(object_id)
            .sort_by { |a| a.pos || 0 }

          AttributeTransformer.new(database).transform_collection(ea_attributes)
        end

        def transform_general_attributes(generalization)
          upper_klass = generalization.general_upper_klass
          gen_name = generalization.general_name
          gen_attrs = generalization.general_attributes

          gen_attrs.map do |attr|
            transformed = attr.dup
            name_ns = case attr.type_ns
                      when "core", "gml"
                        upper_klass
                      else
                        attr.type_ns
                      end
            name_ns = upper_klass if name_ns.nil?
            transformed.name_ns = name_ns
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
            [current_gen.general_attributes,
             current_gen.attributes].each do |attr_list|
              attr_list&.each do |attr|
                attr.upper_klass = current_gen.general_upper_klass
                attr.level = level
              end
            end

            current_gen.attributes.reverse_each do |attr|
              inherited_attr = attr.dup
              inherited_attr.upper_klass = current_gen.general_upper_klass
              inherited_attr.gen_name = current_gen.general_name
              inherited_attr.level = level

              if attr.has_association
                inherited_assoc_props << inherited_attr
              else
                inherited_props << inherited_attr
              end
            end

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
