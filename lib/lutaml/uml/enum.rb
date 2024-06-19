# frozen_string_literal: true

require "lutaml/uml/has_members"
require "lutaml/uml/classifier"
require "lutaml/uml/association"
require "lutaml/uml/top_element_attribute"
require "lutaml/uml/value"

module Lutaml
  module Uml
    class Enum < Classifier
      include HasMembers

      attr_reader :attributes,
                  :members,
                  :modifier,
                  :definition,
                  :keyword,
                  :values

      def initialize(attributes = {})
        super
        @keyword = "enumeration"
      end

      # TODO: delete?
      def attributes=(value)
        @attributes = value.to_a.map do |attr|
          TopElementAttribute.new(attr)
        end
      end

      def values=(value)
        @values = value.to_a.map do |attr|
          Value.new(attr)
        end
      end

      # TODO: reserved name, change
      def methods
        []
      end
    end
  end
end
