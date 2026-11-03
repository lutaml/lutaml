# frozen_string_literal: true

module Lutaml
  module Jsonschema
    # One position of a tuple-form `items` array: either a schema or a
    # boolean schema (`true` accepts anything, `false` accepts nothing).
    class TupleItem < Base
      attribute :schema, Schema
      attribute :boolean_value, :boolean

      def value
        schema.nil? ? boolean_value : schema
      end

      def boolean?
        schema.nil? && !boolean_value.nil?
      end
    end
  end
end
