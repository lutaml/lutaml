# frozen_string_literal: true

module Lutaml
  module Lml
    class InstancesImport
      attr_accessor :format_type, :file, :attributes

      def initialize(data = {})
        @format_type = data[:format_type]
        @file = extract_file_string(data[:file])
        @attributes = process_attributes(data[:attributes])
      end

      private

      def extract_file_string(file)
        file.is_a?(Hash) && file.key?(:string) ? file[:string] : file
      end

      def process_attributes(attrs)
        (attrs || []).map { |attr| build_attribute(attr) }.compact
      end

      def build_attribute(attr)
        return if !attr.is_a?(Hash) || !attr.key?(:key) || !attr.key?(:value)

        value = process_attribute_value(attr[:value])

        TopElementAttribute.new(name: attr[:key], value: value)
      end

      def process_attribute_value(value)
        return value if !value.is_a?(Hash) || !value.key?(:key_value_map)

        value[:key_value_map].each_with_object({}) do |kv, h|
          h[kv[:key]] = kv[:value].is_a?(Hash) && kv[:value].key?(:string) ? kv[:value][:string] : kv[:value]
        end
      end
    end
  end
end