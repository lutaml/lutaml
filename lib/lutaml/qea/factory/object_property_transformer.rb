# frozen_string_literal: true

require_relative "base_transformer"
require "lutaml/uml"

module Lutaml
  module Qea
    module Factory
      # Transforms EA ObjectProperty to UML Property/TaggedValue
      #
      # This transformer converts Enterprise Architect object properties
      # (GML/XML Schema encoding metadata) to UML elements. Object properties
      # are treated as specialized tagged values that enhance UML classes
      # with schema-specific metadata.
      #
      # @example Transform an object property
      #   ea_prop = Models::EaObjectProperty.new(
      #     property_id: 1,
      #     object_id: 684,
      #     property: "isCollection",
      #     value: "false"
      #   )
      #   transformer = ObjectPropertyTransformer.new
      #   uml_tag = transformer.transform(ea_prop)
      class ObjectPropertyTransformer < BaseTransformer
        # Transform EA object property to UML TaggedValue
        #
        # Object properties enhance UML elements with GML/XML encoding
        # metadata. They are transformed into tagged values to preserve
        # this semantic information.
        #
        # @param ea_property [Models::EaObjectProperty] EA object property
        # @return [Lutaml::Uml::TaggedValue, nil] UML tagged value or nil
        def transform(ea_property)
          return nil unless ea_property
          return nil unless ea_property.property

          Lutaml::Uml::TaggedValue.new.tap do |tag|
            tag.name = ea_property.property
            tag.value = ea_property.value || ""
            tag.notes = format_notes(ea_property)
          end
        end

        private

        # Format notes from EA property
        #
        # @param ea_property [Models::EaObjectProperty] EA property
        # @return [String, nil] Formatted notes
        def format_notes(ea_property)
          return nil unless ea_property.notes

          # Clean up EA's note format
          notes = ea_property.notes.strip
          notes.empty? ? nil : notes
        end
      end
    end
  end
end
