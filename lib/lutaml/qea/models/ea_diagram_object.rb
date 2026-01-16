# frozen_string_literal: true

require_relative "base_model"

module Lutaml
  module Qea
    module Models
      # Represents a diagram object from the t_diagramobjects table
      #
      # This model represents the placement of UML elements (classes, packages,
      # etc.) on specific diagrams, including their position and styling.
      class EaDiagramObject < BaseModel
        attribute :diagram_id, Lutaml::Model::Type::Integer
        attribute :ea_object_id, Lutaml::Model::Type::Integer
        attribute :recttop, Lutaml::Model::Type::Integer
        attribute :rectleft, Lutaml::Model::Type::Integer
        attribute :rectright, Lutaml::Model::Type::Integer
        attribute :rectbottom, Lutaml::Model::Type::Integer
        attribute :sequence, Lutaml::Model::Type::Integer
        attribute :objectstyle, Lutaml::Model::Type::String
        attribute :instance_id, Lutaml::Model::Type::Integer

        def self.primary_key_column
          :instance_id
        end

        def self.table_name
          "t_diagramobjects"
        end

        # Create from database row
        #
        # @param row [Hash] Database row with string keys
        # @return [EaDiagramObject, nil] New instance or nil if row is nil
        def self.from_db_row(row) # rubocop:disable Metrics/MethodLength
          return nil if row.nil?

          new(
            diagram_id: row["Diagram_ID"],
            ea_object_id: row["Object_ID"],
            recttop: row["RectTop"],
            rectleft: row["RectLeft"],
            rectright: row["RectRight"],
            rectbottom: row["RectBottom"],
            sequence: row["Sequence"],
            objectstyle: row["ObjectStyle"],
            instance_id: row["Instance_ID"],
          )
        end

        # Get the bounding box of the diagram object
        # @return [Hash] Hash with :top, :left, :right, :bottom, :width, :height
        def bounding_box
          {
            top: recttop,
            left: rectleft,
            right: rectright,
            bottom: rectbottom,
            width: rectright - rectleft,
            height: rectbottom - recttop,
          }
        end

        # Get the center point of the diagram object
        # @return [Hash] Hash with :x, :y coordinates
        def center_point
          {
            x: (rectleft + rectright) / 2,
            y: (recttop + rectbottom) / 2,
          }
        end

        # Parse ObjectStyle string into a hash
        # @return [Hash] Parsed style attributes
        def parsed_style
          return {} unless objectstyle

          objectstyle.split(";").each_with_object({}) do |pair, hash|
            key, value = pair.split("=", 2)
            hash[key] = value if key && value
          end
        end
      end
    end
  end
end
