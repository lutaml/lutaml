# frozen_string_literal: true

require_relative "attribute_definition"

module Lutaml
  module Lml
    module Nodes
      class ClassDefinition
        attr_accessor :name, :parent_class
        attr_reader :attributes, :properties

        def initialize(
          name:,
          parent_class: nil,
          attribute_definitions: [],
          properties: []
        )
          @name = name
          @parent_class = parent_class
          @attributes = attribute_definitions
          @properties = properties
        end
      end
    end
  end
end
