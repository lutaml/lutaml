# frozen_string_literal: true

require_relative "base_model"

module Lutaml
  module Qea
    module Models
      # Represents a diagram link from the t_diagramlinks table
      #
      # This model represents the visual rendering of connectors (associations,
      # generalizations, etc.) on specific diagrams, including their routing
      # geometry and styling.
      class EaDiagramLink < BaseModel
        attribute :diagramid, Lutaml::Model::Type::Integer
        attribute :connectorid, Lutaml::Model::Type::Integer
        attribute :geometry, Lutaml::Model::Type::String
        attribute :style, Lutaml::Model::Type::String
        attribute :hidden, Lutaml::Model::Type::Integer
        attribute :path, Lutaml::Model::Type::String
        attribute :instance_id, Lutaml::Model::Type::Integer

        def self.primary_key_column
          :instance_id
        end

        def self.table_name
          "t_diagramlinks"
        end

        # Check if the link is hidden on the diagram
        # @return [Boolean]
        def hidden?
          hidden == 1
        end

        # Parse the Style string into a hash
        # @return [Hash] Parsed style attributes
        def parsed_style
          return {} unless style

          style.split(";").each_with_object({}) do |pair, hash|
            key, value = pair.split("=", 2)
            hash[key] = value if key && value
          end
        end

        # Parse the Geometry string to extract routing points
        # @return [Hash] Parsed geometry data
        def parsed_geometry
          return {} unless geometry

          parts = geometry.split(",")
          result = {}

          # First 4 values are typically coordinates
          if parts.length >= 4
            result[:coords] = parts[0..3].map(&:strip).map(&:to_i)
          end

          # Remaining parts contain additional metadata
          if parts.length > 4
            result[:metadata] = parts[4..-1].join(",")
          end

          result
        end

        # Extract source and destination object IDs from style
        # @return [Hash] Hash with :source_oid, :dest_oid
        def object_ids
          parsed = parsed_style
          {
            source_oid: parsed["SOID"],
            dest_oid: parsed["EOID"],
          }
        end
      end
    end
  end
end
