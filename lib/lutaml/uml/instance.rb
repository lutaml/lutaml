# frozen_string_literal: true

module Lutaml
  module Uml
    class Instance
      attr_accessor :type, :attributes, :instance, :template, :parent

      def initialize(attributes = {})
        @parent = attributes.dig(:parent, :string)
        @type = attributes[:instance_type]
        @template = process_template_attributes(attributes.dig(:template, :attributes))
        @instance = self.class.new(attributes[:instance]) if attributes[:instance]
        @attributes = process_instance_attributes(attributes[:attributes])
      end

      private

      def process_template_attributes(template_attrs)
        return unless template_attrs
        template_attrs.map { |attr| build_attribute(attr) }.compact
      end

      def process_instance_attributes(attrs)
        (attrs || []).map { |attr| build_attribute(attr) }.compact
      end

      def build_attribute(attr)
        return unless attr.is_a?(Hash)

        if attr.key?(:key) && attr.key?(:value)
          TopElementAttribute.new(name: attr[:key], value: attr[:value], extended: !!attr[:add] || nil)
        elsif attr.key?(:comments)
          TopElementAttribute.new(name: "Comment", value: attr[:comments])
        end
      end
    end
  end
end
