# frozen_string_literal: true

require "lutaml/model"

module Lutaml
  module UmlRepository
    # Immutable value object representing a search result.
    #
    # Wraps a UML element (Class, Attribute, Association, etc.) with metadata
    # about how it matched the search query.
    #
    # Uses lutaml-model for automatic JSON/YAML serialization.
    #
    # @example Creating a search result
    #   result = SearchResult.new(
    #     element: class_obj,
    #     element_type: :class,
    #     qualified_name: "ModelRoot::Package::ClassName",
    #     package_path: "ModelRoot::Package",
    #     match_field: :name,
    #     match_context: {}
    #   )
    class SearchResult < Lutaml::Model::Serializable
      # Type of element (class, attribute, association, enum, datatype)
      attribute :element_type, Lutaml::Model::Type::String

      # Fully qualified name of the element
      attribute :qualified_name, Lutaml::Model::Type::String

      # Package path where element is located
      attribute :package_path, Lutaml::Model::Type::String

      # Which field matched (name, documentation)
      attribute :match_field, Lutaml::Model::Type::String

      # Optional context about the match
      attribute :match_context, Lutaml::Model::Type::Hash, default: -> { {} }

      # The UML element that matched (not serialized - internal use only)
      attr_reader :element

      # Override initialize to accept element parameter
      #
      # @param element [Object] The UML element that matched
      # @param element_type [Symbol, String] Type of element
      # @param qualified_name [String] Fully qualified name
      # @param package_path [String] Package path
      # @param match_field [Symbol, String] Field that matched
      # @param match_context [Hash, nil] Optional context
      def initialize(element_type:, qualified_name:, package_path:,
match_field:, element: nil, match_context: nil)
        # Store element before calling super (not for serialization)
        @element = element

        # Initialize lutaml-model with serializable attributes only
        super(
          element_type: element_type.to_s,
          qualified_name: qualified_name,
          package_path: package_path,
          match_field: match_field.to_s,
          match_context: match_context || {}
        )
      end

      json do
        map "element_type", to: :element_type
        map "qualified_name", to: :qualified_name
        map "package_path", to: :package_path
        map "match_field", to: :match_field
        map "match_context", to: :match_context
      end

      yaml do
        map "element_type", to: :element_type
        map "qualified_name", to: :qualified_name
        map "package_path", to: :package_path
        map "match_field", to: :match_field
        map "match_context", to: :match_context
      end
    end
  end
end
