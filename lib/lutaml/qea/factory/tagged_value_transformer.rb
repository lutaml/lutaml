# frozen_string_literal: true

require_relative "base_transformer"
require "lutaml/uml"

module Lutaml
  module Qea
    module Factory
      # Transforms EA TaggedValue to UML TaggedValue
      #
      # This transformer converts Enterprise Architect tagged value
      # definitions (custom metadata) to standard UML TaggedValue objects.
      #
      # @example Transform a tagged value
      #   ea_tag = Models::EaTaggedValue.new(
      #     property_id: "{GUID}",
      #     element_id: "{ELEMENT-GUID}",
      #     base_class: "ASSOCIATION_SOURCE",
      #     tag_value: "sequenceNumber|15$ea_notes=Unique integer..."
      #   )
      #   transformer = TaggedValueTransformer.new(database)
      #   uml_tag = transformer.transform(ea_tag)
      class TaggedValueTransformer < BaseTransformer
        # Transform EA tagged value to UML TaggedValue
        #
        # @param ea_tag [Models::EaTaggedValue] EA tagged value model
        # @return [Lutaml::Uml::TaggedValue, nil] UML tagged value or nil
        def transform(ea_tag)
          return nil unless ea_tag
          return nil unless ea_tag.tag_name

          Lutaml::Uml::TaggedValue.new.tap do |tag|
            tag.name = ea_tag.tag_name
            tag.value = ea_tag.parsed_value || ""
            tag.notes = ea_tag.parsed_notes
          end
        end
      end
    end
  end
end
