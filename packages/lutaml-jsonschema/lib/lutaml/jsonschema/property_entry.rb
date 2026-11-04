# frozen_string_literal: true

module Lutaml
  module Jsonschema
    class PropertyEntry < Base
      attribute :name, :string
      attribute :schema, Schema
      # Boolean schemas are valid values wherever a schema is: `{a: true}`
      # in `properties`/`$defs`, `{a: false}` in `patternProperties`, etc.
      attribute :schema_boolean, :boolean

      def self.from_schema_value(name, value)
        entry = new(name: name)
        case value
        when true, false
          entry.schema_boolean = value
        when Hash
          entry.schema = Schema.from_json(value.to_json)
        end
        entry
      end

      # The value at this entry: a Schema, a boolean, or nil.
      def schema_value
        schema || schema_boolean
      end

      # Wire form of the value: a JSON hash, a boolean, or nil.
      def schema_json
        return schema_boolean if !schema_boolean.nil?
        return Yeptris::JSON.load(schema.to_json) if schema

        nil
      end

      json do
        map "name", to: :name
        map "schema", to: :schema
      end
    end
  end
end
