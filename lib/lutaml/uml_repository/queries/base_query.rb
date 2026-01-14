# frozen_string_literal: true

module Lutaml
  module UmlRepository
    module Queries
      # Base class for all query services.
      #
      # Provides common functionality for accessing the document and indexes
      # that subclasses can use to implement specific query operations.
      #
      # @example Creating a custom query
      #   class CustomQuery < BaseQuery
      #     def find_something
      #       indexes[:qualified_names]["ModelRoot::MyClass"]
      #     end
      #   end
      #
      #   query = CustomQuery.new(document, indexes)
      #   result = query.find_something
      class BaseQuery
        # Create a new query instance
        #
        # @param document [Lutaml::Uml::Document] The UML document to query
        # @param indexes [Hash] The indexes built by IndexBuilder
        def initialize(document, indexes)
          @document = document
          @indexes = indexes
        end

        protected

        attr_reader :document, :indexes

        # Resolve all associations in the document
        #
        # @return [Array<Lutaml::Uml::Association>] Array of all associations
        def find_class_by_id(class_id)
          indexes[:qualified_names].find do |qualified_name, entity|
            entity.is_a?(Lutaml::Uml::Class) && entity.xmi_id == class_id
          end
        end
      end
    end
  end
end
