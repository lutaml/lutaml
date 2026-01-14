# frozen_string_literal: true

require_relative "base_validator"

module Lutaml
  module Qea
    module Validation
      # Validates association/connector references
      class AssociationValidator < BaseValidator
        def validate
          validate_object_references
          validate_connector_endpoints
        end

        private

        def validate_object_references
          connectors.select(&:association?).each do |conn|
            validate_start_object(conn)
            validate_end_object(conn)
          end
        end

        def validate_start_object(connector)
          return if reference_exists?("t_object", "ea_object_id",
                                      connector.start_object_id)

          result.add_error(
            category: :missing_reference,
            entity_type: :association,
            entity_id: connector.connector_id.to_s,
            entity_name: connector.name || "Unnamed",
            field: "start_object_id",
            reference: connector.start_object_id.to_s,
            message: "Start object #{connector.start_object_id} does not exist",
          )
        end

        def validate_end_object(connector)
          return if reference_exists?("t_object", "ea_object_id",
                                      connector.end_object_id)

          result.add_error(
            category: :missing_reference,
            entity_type: :association,
            entity_id: connector.connector_id.to_s,
            entity_name: connector.name || "Unnamed",
            field: "end_object_id",
            reference: connector.end_object_id.to_s,
            message: "End object #{connector.end_object_id} does not exist",
          )
        end

        def validate_connector_endpoints
          connectors.each do |conn|
            # Validate both endpoints exist
            unless conn.start_object_id && conn.end_object_id
              result.add_error(
                category: :invalid_data,
                entity_type: :connector,
                entity_id: conn.connector_id.to_s,
                entity_name: conn.name || "Unnamed",
                message: "Connector missing start or end object reference",
              )
            end
          end
        end

        def connectors
          @connectors ||= context[:connectors] || []
        end
      end
    end
  end
end
