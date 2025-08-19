# frozen_string_literal: true

module Lutaml
  module Uml
    class InstancesImport
      attr_accessor :format_type, :file, :attributes

      def initialize(data = {})
        @format_type = data[:format_type]
        @file = data[:file].is_a?(Hash) && data[:file].key?(:string) ? data[:file][:string] : data[:file]
        @attributes = (data[:attributes] || []).map do |attr|
          if attr.is_a?(Hash) && attr.key?(:key) && attr.key?(:value)
            if attr[:value].is_a?(Hash) && attr[:value].key?(:key_value_map)
              # Handle key_value_map as a hash
              value = attr[:value][:key_value_map].each_with_object({}) do |kv, h|
                h[kv[:key]] = kv[:value].is_a?(Hash) && kv[:value].key?(:string) ? kv[:value][:string] : kv[:value]
              end
              TopElementAttribute.new(name: attr[:key], value: value)
            else
              TopElementAttribute.new(name: attr[:key], value: attr[:value])
            end
          end
        end.compact
      end
    end
  end
end
