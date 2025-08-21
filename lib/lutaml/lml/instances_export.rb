# frozen_string_literal: true

require 'lutaml/lml/top_element_attribute'

module Lutaml
  module Lml
    class InstancesExport < Lutaml::Model::Serializable
      attribute :format_type, :string
      attribute :attributes, TopElementAttribute

      # def initialize(data = {})
      #   @format_type = data[:format_type]
      #   @attributes = process_attributes(data[:attributes])
      # end

      private

      def process_attributes(attrs)
        (attrs || []).map { |attr| build_attribute(attr) }.compact
      end

      def build_attribute(attr)
        return if !attr.is_a?(Hash) || !attr.key?(:key) || !attr.key?(:value)

        TopElementAttribute.new(name: attr[:key], value: attr[:value])
      end
    end
  end
end