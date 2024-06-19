# frozen_string_literal: true

require "lutaml/uml/classifier"

require "lutaml/uml/has_members"
require "lutaml/uml/association"
require "lutaml/uml/constraint"
require "lutaml/uml/data_type"
require "lutaml/uml/operation"
require "lutaml/uml/top_element_attribute"

module Lutaml
  module Uml
    class Class < Classifier
      include HasMembers

      attr_accessor :nested_classifier,
                    :is_abstract,
                    :type,
                    :package

      attr_reader :associations,
                  :attributes,
                  :members,
                  :modifier,
                  :constraints,
                  :operations,
                  :data_types

      def initialize(attributes = {})
        @nested_classifier = []
        @stereotype = []
        @generalization = []
        @is_abstract = false
        super
      end

      def modifier=(value)
        @modifier = value.to_s # TODO: Validate?
      end

      def attributes=(value)
        @attributes = value.to_a.map do |attr|
          TopElementAttribute.new(attr)
        end
      end

      def associations=(value)
        @associations = value.to_a.map do |attr|
          Association.new(attr.to_h.merge(owner_end: name))
        end
      end

      def constraints=(value)
        @constraints = value.to_a.map do |attr|
          Constraint.new(attr)
        end
      end

      def operations=(value)
        @operations = value.to_a.map do |attr|
          Operation.new(attr)
        end
      end

      def data_types=(value)
        @data_types = value.to_a.map do |attr|
          DataType.new(attr)
        end
      end

      def methods
        # @members&.select { |member| member.class == Method }
        []
      end

      def relationships
        # @members&.select { |member| member.class == ClassRelationship }
        []
      end
    end
  end
end
