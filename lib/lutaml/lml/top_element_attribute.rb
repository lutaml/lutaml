# frozen_string_literal: true

require "lutaml/uml/class"
require_relative "attribute_value"
require "lutaml/lml/cardinality"

module Lutaml
  module Lml
    class TopElementAttribute < Uml::TopElementAttribute
      attribute :properties, TopElementAttribute, collection: true, default: []
      attribute :value, Lutaml::Lml::AttributeValue
      attribute :attributes, TopElementAttribute, collection: true, default: []

      def initialize(attributes = {})
        return if attributes.nil?

        attributes[:name] = attributes[:key] if attributes&.key?(:key)
        attributes[:type], attributes[:value] = process_value(attributes[:value])

        super(attributes)
      end

      def process_value(value)
        return [] if value.nil?

        if value.is_a?(Hash) && value.key?(:instance)
          [nil, Instance.new(value[:instance])]
        elsif value.is_a?(Hash) && value.key?(:list)
          ["Array", value[:list].map { |item| process_value(item).last }]
        elsif value.is_a?(Hash) && value.key?(:string)
          ["String", value[:string]]
        elsif value.is_a?(Hash) && value.key?(:boolean)
          ["Boolean", value[:boolean] == "true"]
        elsif value.is_a?(Hash) && value.key?(:key_value_map)
          hv = value[:key_value_map].each_with_object({}) do |kv, h|
            key, value = kv.values_at(:key, :value)
            h[key.to_sym] = process_value(value).last
          end
          ["Hash", hv]
        elsif value.is_a?(Hash) && value.key?(:number)
          ["Number", value[:number].to_i]
        else
          [value.class.to_s, value]
        end
      end

      def extended=(attribute)
        @extended = attribute
      end

      def attributes=(values)
        @attributes = (values.is_a?(Array) ? values : [values]).map do |attr|
          self.class.new(attr)
        end
      end

      def value
        @value.respond_to?(:value) ? @value.value : @value
      end
    end
  end
end
