# frozen_string_literal: true

require_relative "base_model"

module Lutaml
  module Qea
    module Models
      # Represents a diagram type definition from t_diagramtypes table
      #
      # This table provides reference data for diagram types available in EA.
      # These define the types of UML diagrams that can be created.
      #
      # @example
      #   diagram_type = EaDiagramType.new
      #   diagram_type.diagram_type #=> "Logical"
      #   diagram_type.name #=> "Logical View"
      #   diagram_type.package_id #=> 1
      class EaDiagramType < BaseModel
        attribute :diagram_type, Lutaml::Model::Type::String
        attribute :name, Lutaml::Model::Type::String
        attribute :package_id, Lutaml::Model::Type::Integer

        def self.table_name
          "t_diagramtypes"
        end

        # Primary key is Diagram_Type (text)
        def self.primary_key_column
          "Diagram_Type"
        end

        # Friendly type name
        # @return [String]
        def type_name
          diagram_type
        end

        # Check if this is a class diagram
        # @return [Boolean]
        def class_diagram?
          diagram_type == "Logical"
        end

        # Check if this is an activity diagram
        # @return [Boolean]
        def activity_diagram?
          diagram_type == "Activity"
        end

        # Check if this is a use case diagram
        # @return [Boolean]
        def use_case_diagram?
          diagram_type == "UseCase"
        end
      end
    end
  end
end
