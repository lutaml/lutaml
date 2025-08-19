# frozen_string_literal: true

module Lutaml
  module Uml
    class InstancesExport
      attr_accessor :format_type, :attributes

      def initialize(data = {})
        @format_type = data[:format_type]
        @attributes = (data[:attributes] || []).map do |attr|
          if attr.is_a?(Hash) && attr.key?(:key) && attr.key?(:value)
            TopElementAttribute.new(name: attr[:key], value: attr[:value])
          end
        end.compact
      end
    end
  end
end
