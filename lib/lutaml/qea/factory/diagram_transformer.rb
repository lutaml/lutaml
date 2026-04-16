# frozen_string_literal: true

require_relative "base_transformer"
require "lutaml/uml"
require_relative "../../uml/diagram_object"
require_relative "../../uml/diagram_link"

module Lutaml
  module Qea
    module Factory
      # Transforms EA diagrams to UML diagrams
      #
      # This transformer loads diagram data along with diagram objects
      # (visual placement) and diagram links (visual connector routing)
      # to create a complete UML diagram representation.
      class DiagramTransformer < BaseTransformer
        # Transform EA diagram to UML diagram
        # @param ea_diagram [EaDiagram] EA diagram model
        # @return [Lutaml::Uml::Diagram] UML diagram
        def transform(ea_diagram) # rubocop:disable Metrics/AbcSize,Metrics/CyclomaticComplexity,Metrics/PerceivedComplexity,Metrics/MethodLength
          return nil if ea_diagram.nil?

          Lutaml::Uml::Diagram.new.tap do |diagram| # rubocop:disable Metrics/BlockLength
            # Map basic properties
            diagram.name = ea_diagram.name
            diagram.xmi_id = normalize_guid_to_xmi_format(ea_diagram.ea_guid,
                                                          "EAID")
            # TODO: Fix diagram_type assignment -
            # lutaml-model compatibility issue
            # diagram.diagram_type = ea_diagram.diagram_type

            # Map package relationship - use GUID not numeric ID
            if ea_diagram.package_id
              package = find_package(ea_diagram.package_id)
              if package
                diagram.package_id = normalize_guid_to_xmi_format(
                  package.ea_guid, "EAPK"
                )
                diagram.package_name = package.name
              end
            end

            # Map definition/notes
            diagram.definition = ea_diagram.notes unless
              ea_diagram.notes.nil? || ea_diagram.notes.empty?

            # Map stereotype
            if ea_diagram.stereotype && !ea_diagram.stereotype.empty?
              diagram.stereotype = [ea_diagram.stereotype]
            end

            # Load and transform diagram objects (visual placement)
            diagram_objects = load_diagram_objects(ea_diagram.diagram_id)
            if diagram_objects.any?
              diagram.diagram_objects.concat(diagram_objects)
            end

            # Load and transform diagram links (visual routing)
            diagram_links = load_diagram_links(ea_diagram.diagram_id)
            diagram.diagram_links.concat(diagram_links) if diagram_links.any?

            # Load diagram type
            diagram.diagram_type = ea_diagram.diagram_type

            # Load diagram id
            diagram.package_id = ea_diagram.package_id
          end
        end

        private

        # Find package by ID
        # @param package_id [Integer] Package ID
        # @return [EaPackage, nil] EA package or nil if not found
        def find_package(package_id)
          return nil if package_id.nil?

          query = "SELECT * FROM t_package WHERE Package_ID = ?"
          rows = database.connection.execute(query, package_id)
          return nil if rows.empty?

          Models::EaPackage.from_db_row(rows.first)
        end

        # Load diagram objects for a diagram
        # @param diagram_id [Integer] Diagram ID
        # @return [Array<Lutaml::Uml::DiagramObject>] UML diagram objects
        def load_diagram_objects(diagram_id)
          return [] if diagram_id.nil?

          query = "SELECT * FROM t_diagramobjects WHERE Diagram_ID = ?"
          rows = database.connection.execute(query, diagram_id)

          rows.filter_map do |row|
            ea_obj = Models::EaDiagramObject.from_db_row(row)
            transform_diagram_object(ea_obj)
          end
        end

        # Transform EA diagram object to UML diagram object
        # @param ea_obj [Models::EaDiagramObject] EA diagram object
        # @return [Lutaml::Uml::DiagramObject] UML diagram object
        def transform_diagram_object(ea_obj) # rubocop:disable Metrics/AbcSize,Metrics/MethodLength
          return nil if ea_obj.nil?

          Lutaml::Uml::DiagramObject.new.tap do |obj|
            obj.diagram_object_id = ea_obj.ea_object_id.to_s
            obj.left = ea_obj.rectleft
            obj.top = ea_obj.recttop
            obj.right = ea_obj.rectright
            obj.bottom = ea_obj.rectbottom
            obj.sequence = ea_obj.sequence
            obj.style = ea_obj.objectstyle

            # Try to find and set xmi_id from the referenced object
            if ea_obj.ea_object_id
              uml_object = find_object_by_id(ea_obj.ea_object_id)
              if uml_object
                obj.object_xmi_id = normalize_guid_to_xmi_format(
                  uml_object.ea_guid, "EAID"
                )
              end
            end
          end
        end

        # Load diagram links for a diagram
        # @param diagram_id [Integer] Diagram ID
        # @return [Array<Lutaml::Uml::DiagramLink>] UML diagram links
        def load_diagram_links(diagram_id)
          return [] if diagram_id.nil?

          query = "SELECT * FROM t_diagramlinks WHERE DiagramID = ?"
          rows = database.connection.execute(query, diagram_id)

          rows.filter_map do |row|
            ea_link = Models::EaDiagramLink.from_db_row(row)
            transform_diagram_link(ea_link)
          end
        end

        # Transform EA diagram link to UML diagram link
        # @param ea_link [Models::EaDiagramLink] EA diagram link
        # @return [Lutaml::Uml::DiagramLink] UML diagram link
        def transform_diagram_link(ea_link) # rubocop:disable Metrics/AbcSize,Metrics/MethodLength
          return nil if ea_link.nil?

          Lutaml::Uml::DiagramLink.new.tap do |link|
            link.connector_id = ea_link.connectorid.to_s
            link.geometry = ea_link.geometry
            link.style = ea_link.style
            link.hidden = ea_link.hidden?
            link.path = ea_link.path

            # Try to find and set xmi_id from the referenced connector
            if ea_link.connectorid
              connector = find_connector_by_id(ea_link.connectorid)
              if connector
                link.connector_xmi_id = normalize_guid_to_xmi_format(
                  connector.ea_guid, "EAID"
                )
              end
            end
          end
        end

        # Find connector by ID
        # @param connector_id [Integer] Connector ID
        # @return [Models::EaConnector, nil] EA connector or nil if not found
        def find_connector_by_id(connector_id)
          return nil if connector_id.nil?

          query = "SELECT * FROM t_connector WHERE Connector_ID = ?"
          rows = database.connection.execute(query, connector_id)
          return nil if rows.empty?

          Models::EaConnector.from_db_row(rows.first)
        end
      end
    end
  end
end
