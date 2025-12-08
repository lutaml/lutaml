# frozen_string_literal: true

require_relative "base_transformer"
require_relative "attribute_tag_transformer"
require "lutaml/uml"

module Lutaml
  module Qea
    module Factory
      # Transforms EA attributes to UML attributes
      class AttributeTransformer < BaseTransformer
        # Transform EA attribute to UML attribute
        # @param ea_attribute [EaAttribute] EA attribute model
        # @return [Lutaml::Uml::TopElementAttribute] UML attribute
        def transform(ea_attribute)
          return nil if ea_attribute.nil?

          Lutaml::Uml::TopElementAttribute.new.tap do |attr|
            attr.name = ea_attribute.name
            attr.type = ea_attribute.type
            attr.visibility = map_visibility(ea_attribute.scope)

            # XMI uses the TYPE's XMI ID, not the attribute's ID
            type_xmi_id = lookup_type_xmi_id(ea_attribute.classifier)
            attr.xmi_id = type_xmi_id || normalize_guid_to_xmi_format(ea_attribute.ea_guid, "EAID")

            attr.id = normalize_guid_to_xmi_format(ea_attribute.ea_guid, "EAID")
            attr.static = ea_attribute.static? ? "true" : nil
            attr.is_derived = ea_attribute.derived == "1" ? true : nil

            # Map cardinality if bounds are present
            if ea_attribute.lowerbound || ea_attribute.upperbound
              attr.cardinality = build_cardinality(
                ea_attribute.lowerbound,
                ea_attribute.upperbound,
              )
            end

            # Map definition/notes
            attr.definition = normalize_line_endings(ea_attribute.notes) unless
              ea_attribute.notes.nil? || ea_attribute.notes.empty?

            # Load and transform attribute tags
            attr.tagged_values = load_attribute_tags(ea_attribute.id)
          end
        end

        private

        # Look up the type object's XMI ID from classifier
        # @param classifier_id [Integer] Classifier ID
        # @return [String, nil] Type's XMI ID
        def lookup_type_xmi_id(classifier_id)
          return nil if classifier_id.nil? || classifier_id.to_i == 0

          query = "SELECT ea_guid FROM t_object WHERE Object_ID = ?"
          rows = database.connection.execute(query, [classifier_id])
          return nil if rows.empty?

          ea_guid = rows.first.is_a?(Hash) ? (rows.first['ea_guid'] || rows.first[:ea_guid]) : rows.first[0]
          normalize_guid_to_xmi_format(ea_guid, "EAID")
        end

        # Build cardinality from lower and upper bounds
        # @param lower [String] Lower bound
        # @param upper [String] Upper bound
        # @return [Lutaml::Uml::Cardinality] Cardinality object
        def build_cardinality(lower, upper)
          return nil if lower.nil? && upper.nil?

          Lutaml::Uml::Cardinality.new.tap do |card|
            card.min = lower || "0"
            card.max = upper || "*"
          end
        end

        # Load and transform attribute tags for an attribute
        # @param attribute_id [Integer] Attribute ID
        # @return [Array<Lutaml::Uml::TaggedValue>] UML tagged values
        def load_attribute_tags(attribute_id)
          return [] if attribute_id.nil?
          return [] unless database.attribute_tags

          # Filter attribute tags for this attribute from the in-memory
          # collection
          ea_tags = database.attribute_tags.select do |tag|
            tag.element_id == attribute_id
          end

          # Transform to UML tagged values
          tag_transformer = AttributeTagTransformer.new(database)
          tag_transformer.transform_collection(ea_tags)
        end
      end
    end
  end
end
