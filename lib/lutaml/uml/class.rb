# frozen_string_literal: true

require_relative "top_element"
require_relative "classifier"
require_relative "association"
require_relative "constraint"
require_relative "operation"
require_relative "data_type"
require_relative "generalization"

module Lutaml
  module Uml
    class Class < Classifier
      attribute :nested_classifier, :string, collection: true,
                                             default: -> { [] }
      attribute :is_abstract, :boolean, default: false
      attribute :stereotype, :string, collection: true, default: -> { [] }
      attribute :type, :string
      attribute :attributes, TopElementAttribute, collection: true
      attribute :modifier, :string
      attribute :constraints, Constraint, collection: true
      attribute :operations, Operation, collection: true
      attribute :data_types, DataType, collection: true
      attribute :associations, Association, collection: true
      attribute :generalization, Generalization

      yaml do
        map "nested_classifier", to: :nested_classifier
        map "is_abstract", to: :is_abstract
        map "stereotype", to: :stereotype
        map "type", to: :type
        map "attributes", to: :attributes
        map "modifier", to: :modifier
        map "constraints", to: :constraints
        map "operations", to: :operations
        map "data_types", to: :data_types
        map "associations", to: :associations, with: {
          to: :associations_to_yaml, from: :associations_from_yaml
        }
      end

      def associations_to_yaml(model, doc)
        return unless model.associations

        associations = model.associations.map(&:to_hash)
        doc["associations"] = associations unless associations.empty?
      end

      def associations_from_yaml(model, values)
        associations = values.map do |value|
          value["owner_end"] = model.name if value["owner_end"].nil?
          Association.from_yaml(value.to_yaml)
        end

        model.associations = associations
      end
    end
  end
end
