# frozen_string_literal: true

require "pry"
require "lutaml/uml/class"
require_relative "attribute_value"
require "lutaml/lml/cardinality"

module Lutaml
  module Lml
    class TopElementAttribute < Uml::TopElementAttribute
      attribute :properties, TopElementAttribute, collection: true, default: []
      attribute :value, Lutaml::Lml::AttributeValue
      attribute :attributes, TopElementAttribute, collection: true, default: []
      attribute :extended, :boolean

      def value
        @value.respond_to?(:value) ? @value.value : @value
      end
    end
  end
end
