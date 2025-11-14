# frozen_string_literal: true

require_relative "../base_validator"

module Lutaml
  module Qea
    module Validation
      # Validates referential integrity across all entities
      class ReferentialIntegrityValidator < BaseValidator
        def validate
          validate_all_package_references
          validate_all_object_references
          validate_all_connector_references
        end

        private

        def validate_all_package_references
          # Check all parent_id references in packages
          packages.each do |pkg|
            next if pkg.root?

            unless package_exists?(pkg.parent_id)
              result.add_error(
                category: :referential_integrity,
                entity_type: :package,
                entity_id: pkg.package_id.to_s,
                entity_name: pkg.name,
                field: "parent_id",
                reference: pkg.parent_id.to_s,
                message: "Foreign key violation: parent_id #{pkg.parent_id} " \
                         "not found in t_package",
              )
            end
          end
        end

        def validate_all_object_references
          # Check all package_id references in objects
          objects.each do |obj|
            next unless obj.package_id

            unless package_exists?(obj.package_id)
              result.add_error(
                category: :referential_integrity,
                entity_type: :class,
                entity_id: obj.ea_object_id.to_s,
                entity_name: obj.name,
                field: "package_id",
                reference: obj.package_id.to_s,
                message: "Foreign key violation: package_id " \
                         "#{obj.package_id} not found in t_package",
              )
            end

            # Check classifier references
            next unless obj.classifier&.positive?

            unless object_exists?(obj.classifier)
              result.add_warning(
                category: :referential_integrity,
                entity_type: :class,
                entity_id: obj.ea_object_id.to_s,
                entity_name: obj.name,
                field: "classifier",
                reference: obj.classifier.to_s,
                message: "Classifier object #{obj.classifier} not found",
              )
            end
          end
        end

        def validate_all_connector_references
          # Check all object references in connectors
          connectors.each do |conn|
            unless object_exists?(conn.start_object_id)
              result.add_error(
                category: :referential_integrity,
                entity_type: :connector,
                entity_id: conn.connector_id.to_s,
                entity_name: conn.name || "Unnamed",
                field: "start_object_id",
                reference: conn.start_object_id.to_s,
                message: "Foreign key violation: start_object_id " \
                         "#{conn.start_object_id} not found in t_object",
              )
            end

            unless object_exists?(conn.end_object_id)
              result.add_error(
                category: :referential_integrity,
                entity_type: :connector,
                entity_id: conn.connector_id.to_s,
                entity_name: conn.name || "Unnamed",
                field: "end_object_id",
                reference: conn.end_object_id.to_s,
                message: "Foreign key violation: end_object_id " \
                         "#{conn.end_object_id} not found in t_object",
              )
            end
          end
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
          return false unless package_id

          packages.any? { |p| p.package_id == package_id }
        end

        def object_exists?(object_id)
          return false unless object_id

          objects.any? { |o| o.ea_object_id == object_id }
        end
      end
    end
  end
end
