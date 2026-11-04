# frozen_string_literal: true

module Expressir
  module Interop
    # JSON Schema 2020-12 rendering of an EXPRESS schema. Decisions
    # (docs/interop/json-schema.md): entities become object definitions
    # composed by allOf over their subtype_of supertypes; explicit
    # attributes are properties in declaration order; OPTIONAL
    # attributes leave `required` and admit null; aggregates become
    # arrays with bounds; SELECT becomes anyOf; ENUMERATION becomes a
    # string enum; derived and inverse attributes are not exported
    # (they are not part of the Part 21 exchange structure).
    class JsonSchema
      DRAFT = "https://json-schema.org/draft/2020-12/schema"
      BASE_IRI = "https://expressir.org/json-schema"

      def self.export(schema)
        new(schema).export
      end

      attr_reader :schema

      def initialize(schema)
        @schema = schema
      end

      def export
        result = {
          "$schema" => DRAFT,
          "$id" => "#{BASE_IRI}/#{schema.id}",
          "title" => schema.id.to_s,
          "$defs" => definitions,
        }
        entities = Array(schema.entities)
        result["anyOf"] = entities.map { |entity| reference(entity.id) } unless entities.empty?
        result
      end

      def to_json(pretty: true)
        pretty ? JSON.pretty_generate(export) : JSON.generate(export)
      end

      private

      def definitions
        result = {}
        Array(schema.types).each do |type|
          result[type.id] = defined_type_schema(type)
        end
        Array(schema.entities).each do |entity|
          result[entity.id] = entity_schema(entity)
        end
        result
      end

      def defined_type_schema(type)
        case type.underlying_type
        when Model::DataTypes::Enumeration
          enumeration_schema(type.underlying_type)
        when Model::DataTypes::Select
          select_schema(type.underlying_type)
        else
          type_schema(type.underlying_type)
        end
      end

      def entity_schema(entity)
        own = {
          "type" => "object",
          "properties" => explicit_attributes(entity).to_h do |attribute|
            [attribute.id, attribute_schema(attribute)]
          end,
        }
        required = explicit_attributes(entity).reject(&:optional)
          .map(&:id)
        own["required"] = required unless required.empty?

        supertypes = Array(entity.subtype_of).map do |supertype|
          reference(supertype.id)
        end
        return own.merge("title" => entity.id) if supertypes.empty?

        { "title" => entity.id, "allOf" => [*supertypes, own] }
      end

      def explicit_attributes(entity)
        Array(entity.attributes)
          .select { |attribute| attribute.instance_of?(Model::Declarations::Attribute) }
      end

      def attribute_schema(attribute)
        base = type_schema(attribute.type)
        return base unless attribute.optional

        { "anyOf" => [base, { "type" => "null" }] }
      end

      def type_schema(type)
        case type
        when Model::DataTypes::Integer then { "type" => "integer" }
        when Model::DataTypes::Real, Model::DataTypes::Number
          { "type" => "number" }
        when Model::DataTypes::String then { "type" => "string" }
        when Model::DataTypes::Boolean then { "type" => "boolean" }
        when Model::DataTypes::Logical
          { "enum" => [true, false, nil] }
        when Model::DataTypes::Binary
          { "type" => "string", "pattern" => "\\A[01]*\\z" }
        when Model::DataTypes::Enumeration
          enumeration_schema(type)
        when Model::DataTypes::Select
          select_schema(type)
        when Model::DataTypes::List, Model::DataTypes::Array,
             Model::DataTypes::Set, Model::DataTypes::Bag
          aggregate_schema(type)
        when Model::References::SimpleReference then reference(type.id)
        when nil then {}
        else { "type" => "object" }
        end
      end

      def enumeration_schema(enumeration)
        { "type" => "string",
          "enum" => enumeration_values(enumeration).map(&:to_s) }
      end

      def enumeration_values(enumeration, seen = [])
        return [] if enumeration.nil? || seen.include?(enumeration.object_id)

        seen += [enumeration.object_id]
        values = []
        base_type = resolve_reference(enumeration.based_on)
        if base_type&.underlying_type.is_a?(Model::DataTypes::Enumeration)
          values.concat(enumeration_values(base_type.underlying_type, seen))
        end
        values.concat(Array(enumeration.items).filter_map(&:id))
        values.uniq
      end

      def select_schema(select)
        { "anyOf" => select_schemas(select) }
      end

      def select_schemas(select, seen = [])
        return [] if select.nil? || seen.include?(select.object_id)

        seen += [select.object_id]
        refs = []
        base_type = resolve_reference(select.based_on)
        if base_type&.underlying_type.is_a?(Model::DataTypes::Select)
          refs.concat(select_schemas(base_type.underlying_type, seen))
        end
        refs.concat(Array(select.items).map { |item| type_schema(item) })
        refs.uniq
      end

      def aggregate_schema(type)
        result = { "type" => "array",
                   "items" => type_schema(type.base_type) }
        lower, upper = aggregate_bounds(type)
        result["minItems"] = lower if lower
        result["maxItems"] = upper if upper
        result["uniqueItems"] = true if unique?(type)
        result
      end

      def aggregate_bounds(type)
        [bound_value(type.bound1), bound_value(type.bound2)]
      end

      def bound_value(bound)
        return nil unless bound.is_a?(Model::Literals::Integer)

        bound.value.to_i
      end

      def unique?(type)
        type.is_a?(Model::DataTypes::Set) ||
          (type.is_a?(Model::DataTypes::List) && type.unique)
      end

      def resolve_reference(reference)
        return nil unless reference.respond_to?(:id) && reference.id

        schema.find(reference.id)
      rescue StandardError
        nil
      end

      def reference(id)
        { "$ref" => "#/$defs/#{id}" }
      end
    end
  end
end
