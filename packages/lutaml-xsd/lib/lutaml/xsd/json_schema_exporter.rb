# frozen_string_literal: true

require "json"

module Lutaml
  module Xsd
    # Exports an XSD schema to a JSON Schema 2020-12 document.
    #
    # The mapping covers the common core and deliberately records its
    # losses: XSD regular expressions are not ECMA-262 patterns, identity
    # constraints and substitution groups have no direct JSON Schema
    # equivalent, and derivation is flattened. See docs/JSON_SCHEMA.adoc.
    class JsonSchemaExporter
      DRAFT = "https://json-schema.org/draft/2020-12/schema"

      # Nested particle accessors per container class — declared model
      # attributes on lutaml-model 0.8.114+ (xs:all cannot nest, and
      # only complexType/extension/restriction carry one level of
      # sequence/choice/all).
      PARTICLE_KINDS_BY_CLASS = {
        Lutaml::Xml::Schema::Xsd::ComplexType => %i[sequence choice all],
        Lutaml::Xml::Schema::Xsd::ExtensionComplexContent =>
          %i[sequence choice all],
        Lutaml::Xml::Schema::Xsd::RestrictionComplexContent =>
          %i[sequence choice all],
        Lutaml::Xml::Schema::Xsd::Sequence => %i[sequence choice],
        Lutaml::Xml::Schema::Xsd::Choice => %i[sequence choice],
        Lutaml::Xml::Schema::Xsd::All => [].freeze,
      }.freeze

      BUILTIN_TYPES = {
        "string" => { "type" => "string" },
        "normalizedString" => { "type" => "string" },
        "token" => { "type" => "string" },
        "boolean" => { "type" => "boolean" },
        "decimal" => { "type" => "number" },
        "float" => { "type" => "number" },
        "double" => { "type" => "number" },
        "integer" => { "type" => "integer" },
        "positiveInteger" => { "type" => "integer", "minimum" => 1 },
        "negativeInteger" => { "type" => "integer", "maximum" => -1 },
        "nonPositiveInteger" => { "type" => "integer", "maximum" => 0 },
        "nonNegativeInteger" => { "type" => "integer", "minimum" => 0 },
        "long" => { "type" => "integer" },
        "int" => { "type" => "integer" },
        "short" => { "type" => "integer" },
        "byte" => { "type" => "integer" },
        "unsignedLong" => { "type" => "integer", "minimum" => 0 },
        "unsignedInt" => { "type" => "integer", "minimum" => 0 },
        "unsignedShort" => { "type" => "integer", "minimum" => 0 },
        "unsignedByte" => { "type" => "integer", "minimum" => 0 },
        "date" => { "type" => "string", "format" => "date" },
        "dateTime" => { "type" => "string", "format" => "date-time" },
        "time" => { "type" => "string", "format" => "time" },
        "anyURI" => { "type" => "string", "format" => "uri" },
        "QName" => { "type" => "string" },
      }.freeze

      FACET_MAP = {
        min_length: "minLength",
        max_length: "maxLength",
        min_inclusive: "minimum",
        max_inclusive: "maximum",
        min_exclusive: "exclusiveMinimum",
        max_exclusive: "exclusiveMaximum",
        pattern: "pattern",
      }.freeze

      def initialize(schema)
        @schema = schema
      end

      # @return [Hash] JSON Schema 2020-12 document
      def export
        document = {
          "$schema" => DRAFT,
          "$defs" => {},
        }
        id = @schema.target_namespace
        document["$id"] = id if id && !id.empty?

        Array(@schema.complex_type).each do |complex_type|
          next unless complex_type.name

          document["$defs"][complex_type.name] =
            complex_type_schema(complex_type)
        end

        Array(@schema.simple_type).each do |simple_type|
          next unless simple_type.name

          document["$defs"][simple_type.name] =
            simple_type_schema(simple_type)
        end

        elements = Array(@schema.element)
        elements.each do |element|
          next unless element.name

          document["$defs"][element.name] = element_schema(element)
        end

        unless elements.empty?
          document["oneOf"] = elements.map do |element|
            { "$ref" => "#/$defs/#{element.name}" }
          end
        end

        document
      end

      # @return [String] pretty JSON
      def to_json(pretty: true)
        pretty ? JSON.pretty_generate(export) : JSON.generate(export)
      end

      private

      def complex_type_schema(complex_type)
        if complex_type.simple_content
          return simple_content_schema(complex_type.simple_content)
        end

        schema = { "type" => "object" }
        properties, required = properties_for(complex_type)
        schema["properties"] = properties unless properties.empty?
        schema["required"] = required unless required.empty?
        schema["additionalProperties"] = false
        schema
      end

      def simple_content_schema(simple_content)
        base = simple_content.extension || simple_content.restriction
        content = base && type_schema_for(base)
        content ||= { "type" => "string" }
        content.merge("type" => content["type"] || "string")
      end

      def properties_for(complex_type)
        properties = {}
        required = []

        each_element_particle(complex_type) do |element|
          name = element.name || element.ref
          next unless name

          max_occurs = element.max_occurs.to_s
          max_occurs = "1" if max_occurs.empty?
          min_occurs = element.min_occurs.to_s
          min_occurs = "1" if min_occurs.empty?

          properties[name] = element_schema(element)
          if max_occurs != "1" && max_occurs != "0"
            properties[name] = { "type" => "array", "items" => properties[name] }
            required << name if min_occurs != "0"
          elsif min_occurs != "0"
            required << name
          end
        end

        Array(complex_type.attribute).each do |attribute|
          name = attribute.name || attribute.ref
          next unless name

          properties[name] = attribute_schema(attribute)
          required << name if attribute.use == "required"
        end

        [properties, required]
      end

      def each_element_particle(node, &)
        return unless node

        kinds = PARTICLE_KINDS_BY_CLASS[node.class]
        return unless kinds

        kinds.each do |kind|
          Array(node.public_send(kind)).each do |particle|
            next unless particle

            Array(particle.element).each(&)
            Array(particle.choice).each do |choice|
              each_element_particle(choice, &)
            end
            Array(particle.sequence).each do |seq|
              each_element_particle(seq, &)
            end
          end
        end

        return unless node.is_a?(Lutaml::Xml::Schema::Xsd::ComplexType)

        content = node.complex_content
        return unless content

        %i[extension restriction].each do |kind|
          part = content.public_send(kind)
          each_element_particle(part, &) if part
        end
      end

      def element_schema(element)
        schema = if element.complex_type
                   complex_type_schema(element.complex_type)
                 elsif element.simple_type
                   simple_type_schema(element.simple_type)
                 elsif element.type
                   type_schema_for(element.type)
                 else
                   { "type" => "string" }
                 end

        schema = { "type" => ["null", schema["type"]] }.merge(schema.except("type")) if ["true", true].include?(element.nillable)

        schema = { "const" => element.fixed } if element.fixed && !schema.key?("const")
        schema
      end

      def attribute_schema(attribute)
        schema = if attribute.simple_type
                   simple_type_schema(attribute.simple_type)
                 elsif attribute.type
                   type_schema_for(attribute.type)
                 else
                   { "type" => "string" }
                 end

        schema = { "const" => attribute.fixed } if attribute.fixed
        schema
      end

      def simple_type_schema(simple_type)
        restriction = simple_type.restriction
        return type_schema_for(restriction.base) if restriction.nil? || restriction.base.nil?

        schema = type_schema_for(restriction.base)

        Array(restriction.enumeration).each { |e| (schema["enum"] ||= []) << e.value }
        FACET_MAP.each do |facet, json_key|
          value = Array(restriction.public_send(facet)).first
          schema[json_key] = facet_value(value, json_key) if value
        rescue NoMethodError
          next
        end

        schema
      end

      def facet_value(value, json_key)
        return value.to_i if %w[minLength maxLength].include?(json_key)

        return value.to_f if %w[minimum maximum exclusiveMinimum exclusiveMaximum].include?(json_key)

        value
      end

      def type_schema_for(type_name)
        local = type_name.to_s.split(":").last
        builtin = BUILTIN_TYPES[local]
        return builtin.dup if builtin

        { "$ref" => "#/$defs/#{local}" }
      end
    end
  end
end
