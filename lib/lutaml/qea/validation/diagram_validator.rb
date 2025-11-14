# frozen_string_literal: true

require_relative "base_validator"

module Lutaml
  module Qea
    module Validation
      # Validates diagram references and structure
      class DiagramValidator < BaseValidator
        def validate
          validate_package_references
          validate_diagram_objects
          validate_diagram_links
        end

        private

        def validate_package_references
          diagrams.each do |diagram|
            next unless diagram.package_id

            unless package_exists?(diagram.package_id)
              result.add_error(
                category: :missing_reference,
                entity_type: :diagram,
                entity_id: diagram.diagram_id.to_s,
                entity_name: diagram.name,
                field: "package_id",
                reference: diagram.package_id.to_s,
                message: "Package #{diagram.package_id} does not exist",
              )
            end
          end
        end

        def validate_diagram_objects
          diagram_objects.each do |diag_obj|
            unless object_exists?(diag_obj.ea_object_id)
              diagram = diagrams.find do |d|
                d.diagram_id == diag_obj.diagram_id
              end
              result.add_warning(
                category: :missing_reference,
                entity_type: :diagram_object,
                entity_id: diag_obj.instance_id.to_s,
                entity_name: diagram&.name || "Unknown diagram",
                field: "object_id",
                reference: diag_obj.ea_object_id.to_s,
                message: "Diagram object references non-existent " \
                         "object #{diag_obj.ea_object_id}",
              )
            end
          end
        end

        def validate_diagram_links
          diagram_links.each do |diag_link|
            unless connector_exists?(diag_link.connectorid)
              diagram = diagrams.find do |d|
                d.diagram_id == diag_link.diagramid
              end
              result.add_warning(
                category: :missing_reference,
                entity_type: :diagram_link,
                entity_id: diag_link.instance_id.to_s,
                entity_name: diagram&.name || "Unknown diagram",
                field: "connectorid",
                reference: diag_link.connectorid.to_s,
                message: "Diagram link references non-existent " \
                         "connector #{diag_link.connectorid}",
              )
            end
          end
        end

        def diagrams
          @diagrams ||= context[:diagrams] || []
        end

        def diagram_objects
          @diagram_objects ||= context[:diagram_objects] || []
        end

        def diagram_links
          @diagram_links ||= context[:diagram_links] || []
        end

        def packages
          @packages ||= context[:db_packages] || []
        end

        def objects
          @objects ||= context[:db_objects] || []
        end

        def connectors
          @connectors ||= context[:connectors] || []
        end

        def package_exists?(package_id)
          packages.any? { |p| p.package_id == package_id }
        end

        def object_exists?(object_id)
          objects.any? { |o| o.ea_object_id == object_id }
        end

        def connector_exists?(connector_id)
          connectors.any? { |c| c.connector_id == connector_id }
        end
      end
    end
  end
end
