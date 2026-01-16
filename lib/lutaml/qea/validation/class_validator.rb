# frozen_string_literal: true

require_relative "base_validator"

module Lutaml
  module Qea
    module Validation
      # Validates class/object references and structure
      class ClassValidator < BaseValidator
        def validate
          validate_package_references
          validate_duplicate_names
          validate_generalization_parents
        end

        private

        def validate_package_references # rubocop:disable Metrics/AbcSize,Metrics/MethodLength
          objects.each do |obj|
            next unless obj.package_id

            unless package_exists?(obj.package_id)
              class_path = resolve_class_path(obj.ea_object_id, obj.name)
              result.add_error(
                category: :missing_reference,
                entity_type: :class,
                entity_id: obj.ea_object_id.to_s,
                entity_name: obj.name,
                field: "package_id",
                reference: obj.package_id.to_s,
                message: "Package #{obj.package_id} does not exist",
                location: class_path,
              )
            end
          end
        end

        def validate_duplicate_names # rubocop:disable Metrics/AbcSize,Metrics/CyclomaticComplexity,Metrics/MethodLength,Metrics/PerceivedComplexity
          objects_by_package = objects.group_by(&:package_id)

          objects_by_package.each do |package_id, package_objects|
            names = package_objects.map(&:name)
            duplicates = names.select { |name| names.count(name) > 1 }.uniq

            duplicates.each do |dup_name|
              dup_objects = package_objects.select { |o| o.name == dup_name }
              dup_objects.each do |obj|
                class_path = resolve_class_path(obj.ea_object_id, obj.name)
                package_path = if package_id
                                 resolve_package_path(package_id)
                               else
                                 "Root"
                               end
                result.add_warning(
                  category: :duplicate,
                  entity_type: :class,
                  entity_id: obj.ea_object_id.to_s,
                  entity_name: obj.name,
                  field: "name",
                  message: "Duplicate class name '#{dup_name}' " \
                           "in #{package_path}",
                  location: class_path,
                )
              end
            end
          end
        end

        def validate_generalization_parents # rubocop:disable Metrics/AbcSize,Metrics/MethodLength,Metrics/CyclomaticComplexity,Metrics/PerceivedComplexity
          connectors.select(&:generalization?).each do |gen|
            parent_id = gen.end_object_id

            unless object_exists?(parent_id)
              child = objects.find { |o| o.ea_object_id == gen.start_object_id }
              child_path = if child
                             resolve_class_path(child.ea_object_id,
                                                child.name)
                           else
                             "Unknown"
                           end
              result.add_error(
                category: :missing_reference,
                entity_type: :generalization,
                entity_id: gen.connector_id.to_s,
                entity_name: child&.name || "Unknown",
                field: "end_object_id",
                reference: parent_id.to_s,
                message: "Generalization parent #{parent_id} does not exist",
                location: child_path,
              )
            end
          end
        end

        def objects
          @objects ||= begin
            # Use database objects for referential integrity checks
            # Filter to only Class and Interface types (exclude Notes, etc.)
            all_objects = context[:db_objects] || context[:objects] || []
            all_objects.select { |obj| obj.uml_class? || obj.interface? }
          end
        end

        def packages
          # Use database packages for referential integrity checks
          @packages ||= context[:db_packages] || context[:packages] || []
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
      end
    end
  end
end
