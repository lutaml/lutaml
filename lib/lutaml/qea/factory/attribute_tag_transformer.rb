# frozen_string_literal: true

require_relative "base_transformer"
require "lutaml/uml"

module Lutaml
  module Qea
    module Factory
      # Transforms EA AttributeTag to UML TaggedValue
      #
      # This transformer converts Enterprise Architect attribute tags
      # (GML/XML Schema encoding metadata for attributes) to UML
      # TaggedValue objects.
      #
      # @example Transform an attribute tag
      #   ea_tag = Models::EaAttributeTag.new(
      #     property_id: 1,
      #     element_id: 367,
      #     property: "isMetadata",
      #     value: "false"
      #   )
      #   transformer = AttributeTagTransformer.new
      #   uml_tag = transformer.transform(ea_tag)
      class AttributeTagTransformer < BaseTransformer
        # Transform EA attribute tag to UML TaggedValue
        #
        # Attribute tags enhance UML attributes with GML/XML encoding
        # metadata. They are transformed into tagged values to preserve
        # this semantic information.
        #
        # @param ea_tag [Models::EaAttributeTag] EA attribute tag
        # @return [Lutaml::Uml::TaggedValue, nil] UML tagged value or nil
        def transform(ea_tag)
          return nil unless ea_tag
          return nil unless ea_tag.property

          Lutaml::Uml::TaggedValue.new.tap do |tag|
            tag.name = ea_tag.property
            tag.value = ea_tag.value || ""
            tag.notes = format_notes(ea_tag)
          end
        end

        private

        # Format notes from EA attribute tag
        #
        # @param ea_tag [Models::EaAttributeTag] EA tag
        # @return [String, nil] Formatted notes
        def format_notes(ea_tag)
          return nil unless ea_tag.notes

          # Clean up EA's note format
          notes = ea_tag.notes.strip
          notes.empty? ? nil : notes
        end
      end
    end
  end
end
