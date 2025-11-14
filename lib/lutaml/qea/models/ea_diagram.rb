# frozen_string_literal: true

require_relative "base_model"

module Lutaml
  module Qea
    module Models
      # Represents a diagram from the t_diagram table in EA database
      # This represents visual diagrams in the model
      class EaDiagram < BaseModel
        attribute :diagram_id, Lutaml::Model::Type::Integer
        attribute :package_id, Lutaml::Model::Type::Integer
        attribute :parentid, Lutaml::Model::Type::Integer
        attribute :diagram_type, Lutaml::Model::Type::String
        attribute :name, Lutaml::Model::Type::String
        attribute :version, Lutaml::Model::Type::String
        attribute :author, Lutaml::Model::Type::String
        attribute :showdetails, Lutaml::Model::Type::Integer
        attribute :notes, Lutaml::Model::Type::String
        attribute :stereotype, Lutaml::Model::Type::String
        attribute :attPub, Lutaml::Model::Type::Integer
        attribute :attPri, Lutaml::Model::Type::Integer
        attribute :attPro, Lutaml::Model::Type::Integer
        attribute :orientation, Lutaml::Model::Type::String
        attribute :cx, Lutaml::Model::Type::Integer
        attribute :cy, Lutaml::Model::Type::Integer
        attribute :scale, Lutaml::Model::Type::Integer
        attribute :createddate, Lutaml::Model::Type::String
        attribute :modifieddate, Lutaml::Model::Type::String
        attribute :htmlpath, Lutaml::Model::Type::String
        attribute :showforeign, Lutaml::Model::Type::Integer
        attribute :showborder, Lutaml::Model::Type::Integer
        attribute :showpackagecontents, Lutaml::Model::Type::Integer
        attribute :pdata, Lutaml::Model::Type::String
        attribute :locked, Lutaml::Model::Type::Integer
        attribute :ea_guid, Lutaml::Model::Type::String
        attribute :tpos, Lutaml::Model::Type::Integer
        attribute :swimlanes, Lutaml::Model::Type::String
        attribute :styleex, Lutaml::Model::Type::String

        def self.primary_key_column
          :diagram_id
        end

        def self.table_name
          "t_diagram"
        end

        # Check if diagram shows details
        # @return [Boolean]
        def show_details?
          showdetails == 1
        end

        # Check if diagram shows foreign elements
        # @return [Boolean]
        def show_foreign?
          showforeign == 1
        end

        # Check if diagram shows border
        # @return [Boolean]
        def show_border?
          showborder == 1
        end

        # Check if diagram shows package contents
        # @return [Boolean]
        def show_package_contents?
          showpackagecontents == 1
        end

        # Check if diagram is locked
        # @return [Boolean]
        def locked?
          locked == 1
        end

        # Check if orientation is portrait
        # @return [Boolean]
        def portrait?
          orientation == "P"
        end

        # Check if orientation is landscape
        # @return [Boolean]
        def landscape?
          orientation == "L"
        end

        # Check if diagram is a class diagram
        # @return [Boolean]
        def class_diagram?
          diagram_type == "Logical"
        end

        # Check if diagram is a use case diagram
        # @return [Boolean]
        def use_case_diagram?
          diagram_type == "Use Case"
        end

        # Check if diagram is a sequence diagram
        # @return [Boolean]
        def sequence_diagram?
          diagram_type == "Sequence"
        end

        # Check if diagram is an activity diagram
        # @return [Boolean]
        def activity_diagram?
          diagram_type == "Activity"
        end
      end
    end
  end
end
