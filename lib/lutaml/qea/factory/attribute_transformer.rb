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
            attr.xmi_id = normalize_guid_to_xmi_format(ea_attribute.ea_guid, "EAID")
            attr.id = normalize_guid_to_xmi_format(ea_attribute.ea_guid, "EAID")
            attr.static = ea_attribute.static? ? "true" : nil
            attr.is_derived = ea_attribute.derived == "1"

            # Map cardinality if bounds are present
            if ea_attribute.lowerbound || ea_attribute.upperbound
              attr.cardinality = build_cardinality(
                ea_attribute.lowerbound,
                ea_attribute.upperbound,
              )
            end

            # Map definition/notes
            attr.definition = ea_attribute.notes unless
              ea_attribute.notes.nil? || ea_attribute.notes.empty?

            # Load and transform attribute tags
            attr.tagged_values = load_attribute_tags(ea_attribute.id)
          end
        end

        private

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
