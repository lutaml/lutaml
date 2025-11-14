# frozen_string_literal: true

require_relative "../base_validator"

module Lutaml
  module Qea
    module Validation
      # Detects orphaned entities (invalid foreign keys)
      class OrphanValidator < BaseValidator
        def validate
          find_orphaned_objects
          find_orphaned_attributes
          find_orphaned_operations
          find_unreferenced_objects
        end

        private

        def find_orphaned_objects
          objects.each do |obj|
            next unless obj.package_id
            next if package_exists?(obj.package_id)

            result.add_error(
              category: :orphaned,
              entity_type: :class,
              entity_id: obj.ea_object_id.to_s,
              entity_name: obj.name,
              field: "package_id",
              reference: obj.package_id.to_s,
              message: "Orphaned object: package #{obj.package_id} " \
                       "does not exist",
            )
          end
        end

        def find_orphaned_attributes
          attributes.each do |attr|
            next if object_exists?(attr.ea_object_id)

            result.add_error(
              category: :orphaned,
              entity_type: :attribute,
              entity_id: attr.id.to_s,
              entity_name: attr.name,
              field: "object_id",
              reference: attr.ea_object_id.to_s,
              message: "Orphaned attribute: parent object " \
                       "#{attr.ea_object_id} does not exist",
            )
          end
        end

        def find_orphaned_operations
          operations.each do |op|
            next if object_exists?(op.ea_object_id)

            result.add_error(
              category: :orphaned,
              entity_type: :operation,
              entity_id: op.operationid.to_s,
              entity_name: op.name,
              field: "object_id",
              reference: op.ea_object_id.to_s,
              message: "Orphaned operation: parent object " \
                       "#{op.ea_object_id} does not exist",
            )
          end
        end

        def find_unreferenced_objects
          # Find objects that are not referenced by any connector,
          # attribute, or diagram
          object_ids = objects.to_set(&:ea_object_id)

          referenced_ids = Set.new

          # Objects referenced by connectors
          connectors.each do |conn|
            referenced_ids << conn.start_object_id
            referenced_ids << conn.end_object_id
          end

          # Objects referenced by attributes (as classifiers)
          attributes.each do |attr|
            referenced_ids << attr.ea_object_id
            if attr.classifier&.to_i&.positive?
              referenced_ids << attr.classifier.to_i
            end
          end

          # Objects referenced by operations
          operations.each do |op|
            referenced_ids << op.ea_object_id
          end

          # Objects referenced by diagrams
          diagram_objects.each do |diag_obj|
            referenced_ids << diag_obj.ea_object_id
          end

          # Unreferenced objects (except root packages which may be unreferenced)
          unreferenced = object_ids - referenced_ids
          unreferenced.each do |obj_id|
            obj = objects.find { |o| o.ea_object_id == obj_id }
            next unless obj
            # Skip DataType and Enumeration as they may not be referenced
            next if obj.data_type? || obj.enumeration?

            result.add_info(
              category: :unreferenced,
              entity_type: :class,
              entity_id: obj_id.to_s,
              entity_name: obj.name,
              message: "Unreferenced object (not used in any relationship)",
            )
          end
        end

        def packages
          @packages ||= context[:db_packages] || []
        end

        def objects
          @objects ||= context[:db_objects] || []
        end

        def attributes
          @attributes ||= context[:attributes] || []
        end

        def operations
          @operations ||= context[:operations] || []
        end

        def connectors
          @connectors ||= context[:connectors] || []
        end

        def diagram_objects
          @diagram_objects ||= context[:diagram_objects] || []
        end

        def package_exists?(package_id)
          packages.any? { |p| p.package_id == package_id }
        end

        def object_exists?(object_id)
          objects.any? { |o| o.ea_object_id == object_id }
        end
      end
    end
  end
end
