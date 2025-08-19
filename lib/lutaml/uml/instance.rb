# frozen_string_literal: true

module Lutaml
  module Uml
    class Instance
      attr_accessor :type, :attributes, :instance, :template, :parent

      def initialize(attributes = {})
        @parent = attributes.dig(:parent, :string)
        @type = attributes[:instance_type]
        @template = attributes.dig(:template, :attributes)&.map do |attr|
          if attr.is_a?(Hash) && attr.key?(:key) && attr.key?(:value)
            TopElementAttribute.new(name: attr[:key], value: attr[:value])
          elsif attr.is_a?(Hash) && attr.key?(:comments)
            TopElementAttribute.new(name: "Comment", value: attr[:comments])
          end
        end
        @instance = self.class.new(attributes[:instance]) if attributes[:instance]
        @attributes = (attributes[:attributes] || []).map do |attr|
          if attr.is_a?(Hash) && attr.key?(:key) && attr.key?(:value)
            TopElementAttribute.new(name: attr[:key], value: attr[:value], extended: !!attr[:add] || nil)
          elsif attr.is_a?(Hash) && attr.key?(:comments)
            TopElementAttribute.new(name: "Comment", value: attr[:comments])
          end
        end
      end
    end
  end
end
