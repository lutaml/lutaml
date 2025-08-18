# frozen_string_literal: true

module Lutaml
  module Uml
    class Instance
      attr_accessor :instance_type, :attributes, :instance

      def initialize(attributes = {})
        @instance_type = attributes[:instance_type] || attributes["instance_type"]
        @instance = self.class.new(attributes[:instance]) if attributes[:instance]
        @attributes = (attributes[:attributes] || attributes["attributes"] || []).map do |attr|
          if attr.is_a?(Hash) && attr.key?(:key) && attr.key?(:value)
            TopElementAttribute.new(name: attr[:key], value: attr[:value])
          elsif attr.is_a?(Hash) && attr.key?(:comments)
            TopElementAttribute.new(name: "Comment", value: attr[:comments])
          end
        end
      end
    end
  end
end
