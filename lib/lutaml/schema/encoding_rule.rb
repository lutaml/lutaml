# frozen_string_literal: true

module Lutaml
  module Schema
    # Decides how a UML class's attributes are realized in XML, reading generic
    # tagged values on each attribute:
    #
    # - +xmlAttribute+ (truthy: true/yes/1) -> rendered as an XSD +<attribute>+
    # - +sequenceNumber+ (an integer)       -> element ordering, ascending
    #
    # Everything without +xmlAttribute+ is an +<element>+; elements without a
    # +sequenceNumber+ keep their declaration order, after the numbered ones.
    # +sequenceNumber+ is the conventional Enterprise Architect / ShapeChange
    # tag. This is the default rule; a different one can be injected into
    # {Bridge} to support other conventions without touching the model.
    class EncodingRule
      ATTRIBUTE_TAG = "xmlAttribute"
      SEQUENCE_TAG = "sequenceNumber"
      TRUTHY = %w[true yes 1].freeze

      # Partition and order a class's attributes.
      #
      # @param attributes [Enumerable, nil] the UML attributes
      # @return [Hash] +{ elements: [ordered attrs], attributes: [attrs] }+
      def classify(attributes)
        list = attributes ? attributes.to_a : []
        xml_attributes, elements = list.each_with_index.to_a
          .partition { |(attribute, _index)| xml_attribute?(attribute) }
        {
          elements: order_elements(elements),
          attributes: xml_attributes.map(&:first),
        }
      end

      # @return [Boolean] whether the attribute is tagged as an XML attribute
      def xml_attribute?(attribute)
        value = tag_value(attribute, ATTRIBUTE_TAG)
        TRUTHY.include?(value.to_s.strip.downcase)
      end

      private

      # Stable: by sequenceNumber ascending, then declaration order.
      def order_elements(indexed_elements)
        indexed_elements.sort_by do |(attribute, index)|
          [sequence_number(attribute) || Float::INFINITY, index]
        end.map(&:first)
      end

      def sequence_number(attribute)
        Integer(tag_value(attribute, SEQUENCE_TAG).to_s.strip, exception: false)
      end

      def tag_value(attribute, name)
        tags = attribute.tagged_values
        return nil unless tags

        tags.find { |tagged_value| tagged_value.name == name }&.value
      end
    end
  end
end
