# frozen_string_literal: true

require "lutaml/uml/class"

module Lutaml
  module Lml
    class TopElementAttribute < Uml::TopElementAttribute
      attr_accessor :properties, :value, :attributes

      def initialize(attributes = {})
        @properties = {}

        super(attributes)
      end

      def properties=(values)
        values.each do |value|
          property, property_value = value.values_at(:name, :value)
          property_value = property_value[:string] if property_value.is_a?(Hash) && property_value.key?(:string)

          next public_send(:"#{property}=", property_value) if respond_to?("#{property}=")

          properties[property] = property_value
        end
      end


      def value=(value)
        @value = process_value(value)
      end

      def process_value(value)
        if value.is_a?(Hash) && value.key?(:instance)
          Instance.new(value[:instance])
        elsif value.is_a?(Hash) && value.key?(:list)
          @type = "Array"
          value[:list].map { |item| process_value(item) }
        elsif value.is_a?(Hash) && value.key?(:string)
          @type = "String"
          value[:string]
        elsif value.is_a?(Hash) && value.key?(:boolean)
          @type = "Boolean"
          value[:boolean] == "true"
        elsif value.is_a?(Hash) && value.key?(:number)
          @type = "Number"
          value[:number].to_i
        else
          @type = value.class.to_s
          value
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
    end
  end
end
