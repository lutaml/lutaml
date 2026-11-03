# frozen_string_literal: true

require "rexml/document"
require "rexml/formatters/pretty"

module Lutaml
  module Jsonschema
    module Exports
      # Renders a SchemaSet as a W3C XML Schema (xs:schema).
      #
      # Approximation notes: JSON Schema objects become xs:complexType
      # sequences; `additionalProperties` has no XSD analogue and is
      # dropped; unions collapse to their first member; `$ref` members
      # become tns: type references to the definition types.
      class Xsd
        XS_NS = "http://www.w3.org/2001/XMLSchema"
        SCALAR_TYPES = {
          "string" => "xs:string",
          "integer" => "xs:integer",
          "number" => "xs:decimal",
          "boolean" => "xs:boolean",
          "null" => "xs:string",
        }.freeze

        def initialize(schema_set, target_namespace: "urn:lutaml:jsonschema")
          @schema_set = schema_set
          @namespace = target_namespace
        end

        def render
          doc = REXML::Document.new
          root = doc.add_element(
            "xs:schema",
            "xmlns:xs" => XS_NS,
            "xmlns:tns" => @namespace,
            "targetNamespace" => @namespace,
            "elementFormDefault" => "qualified",
          )
          @schema_set.schemas.each do |name, schema|
            add_definitions(root, schema)
            add_root_element(root, name, schema)
          end

          output = +""
          REXML::Formatters::Pretty.new(2).write(doc, output)
          "#{output}\n"
        end

        private

        def add_definitions(root, schema)
          schema.definition_entries.each do |entry|
            add_named_type(root, entry.name, entry.schema_value)
          end
        end

        def add_named_type(root, name, schema)
          return unless schema.is_a?(Schema)

          name = type_name(name)
          if object_shaped?(schema)
            type = root.add_element("xs:complexType", "name" => name)
            add_complex_body(type, schema)
          elsif schema.enum&.any?
            add_enum_simple_type(root, name, schema)
          else
            root.add_element(
              "xs:simpleType", "name" => name
            ).add_element("xs:restriction", "base" => scalar_type(schema))
          end
        end

        def add_enum_simple_type(root, name, schema)
          simple = root.add_element("xs:simpleType", "name" => name)
          restriction = simple.add_element("xs:restriction",
                                           "base" => scalar_type(schema))
          schema.enum.each do |value|
            restriction.add_element("xs:enumeration", "value" => value)
          end
        end

        def add_root_element(root, name, schema)
          element = root.add_element("xs:element", "name" => name)
          if object_shaped?(schema)
            type = element.add_element("xs:complexType")
            add_complex_body(type, schema)
          else
            element.add_attribute("type", scalar_type(schema))
          end
        end

        def add_complex_body(type, schema)
          sequence = type.add_element("xs:sequence")
          schema.property_entries.each do |entry|
            add_member(sequence, entry, schema)
          end
        end

        def add_member(sequence, entry, parent)
          schema = entry.schema_value
          element = sequence.add_element("xs:element", "name" => entry.name)
          element.add_attribute("minOccurs", "0") unless
            parent.required.include?(entry.name)
          fill_element_type(element, schema)
        end

        def fill_element_type(element, schema)
          return unless schema.is_a?(Schema)

          type = declared_type(schema)
          if type
            element.add_attribute("type", type)
          else
            add_structured_content(element, schema)
          end
        end

        def declared_type(schema)
          if schema.dollar_ref
            return "tns:#{type_name(ref_name(schema.dollar_ref))}"
          end
          return scalar_type(schema) if plain_scalar?(schema)

          nil
        end

        def plain_scalar?(schema)
          !array?(schema) && schema.enum.nil? && !object_shaped?(schema)
        end

        def add_structured_content(element, schema)
          if array?(schema)
            element.add_attribute("maxOccurs", "unbounded")
            add_item_content(element, schema.items)
          elsif schema.enum&.any?
            add_inline_enum(element, schema)
          else
            add_complex_body(element.add_element("xs:complexType"), schema)
          end
        end

        def add_item_content(element, item)
          return if item.nil? || item == true || item == false
          return element.add_attribute("type", "tns:#{type_name(ref_name(item.dollar_ref))}") if item.dollar_ref
          return add_complex_body(element.add_element("xs:complexType"), item) if object_shaped?(item)

          element.add_attribute("type", scalar_type(item))
        end

        def add_inline_enum(element, schema)
          simple = element.add_element("xs:simpleType")
          restriction = simple.add_element("xs:restriction",
                                           "base" => scalar_type(schema))
          schema.enum.each do |value|
            restriction.add_element("xs:enumeration", "value" => value)
          end
        end

        def object_shaped?(schema)
          schema.type == "object" || schema.property_entries.any?
        end

        def array?(schema)
          schema.type == "array"
        end

        def scalar_type(schema)
          SCALAR_TYPES[schema.types.first] || "xs:anyType"
        end

        def ref_name(ref)
          ref.to_s.start_with?("#/") ? ref.split("/").last : ref
        end

        # XSD NCNames: letters/digits/_/-/., starting with letter or _.
        def type_name(name)
          sanitized = name.to_s.gsub(/[^A-Za-z0-9_.-]/, "_")
          sanitized.match?(/\A[A-Za-z_]/) ? sanitized : "_#{sanitized}"
        end
      end
    end
  end
end
