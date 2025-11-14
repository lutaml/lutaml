# frozen_string_literal: true

require_relative "base_validator"

module Lutaml
  module Qea
    module Validation
      # Validates package structure and hierarchy
      class PackageValidator < BaseValidator
        def validate
          validate_parent_references
          validate_duplicate_names
          validate_circular_hierarchy
        end

        private

        def validate_parent_references
          packages.each do |package|
            next if package.root?

            unless parent_exists?(package.parent_id)
              package_path = resolve_package_path(package.package_id)
              result.add_error(
                category: :missing_reference,
                entity_type: :package,
                entity_id: package.package_id.to_s,
                entity_name: package.name,
                field: "parent_id",
                reference: package.parent_id.to_s,
                message: "Parent package #{package.parent_id} does not exist",
                location: package_path,
              )
            end
          end
        end

        def validate_duplicate_names
          packages_by_parent = packages.group_by(&:parent_id)

          packages_by_parent.each do |parent_id, sibling_packages|
            names = sibling_packages.map(&:name)
            duplicates = names.select { |name| names.count(name) > 1 }.uniq

            duplicates.each do |dup_name|
              dup_packages = sibling_packages.select { |p| p.name == dup_name }
              dup_packages.each do |package|
                package_path = resolve_package_path(package.package_id)
                parent_path = parent_id ? resolve_package_path(parent_id) : "Root"
                result.add_warning(
                  category: :duplicate,
                  entity_type: :package,
                  entity_id: package.package_id.to_s,
                  entity_name: package.name,
                  field: "name",
                  message: "Duplicate package name '#{dup_name}' in parent #{parent_path}",
                  location: package_path,
                )
              end
            end
          end
        end

        def validate_circular_hierarchy
          packages.each do |package|
            next if package.root?

            path = [package.package_id]
            current_id = package.parent_id

            while current_id && !current_id.zero?
              if path.include?(current_id)
                package_path = resolve_package_path(package.package_id)
                result.add_error(
                  category: :circular_reference,
                  entity_type: :package,
                  entity_id: package.package_id.to_s,
                  entity_name: package.name,
                  field: "parent_id",
                  message: "Circular package hierarchy detected: " \
                           "#{path.join(' -> ')} -> #{current_id}",
                  location: package_path,
                )
                break
              end

              path << current_id
              parent = packages.find { |p| p.package_id == current_id }
              break unless parent

              current_id = parent.parent_id
            end
          end
        end

        def packages
          @packages ||= context[:db_packages] || []
        end

        def parent_exists?(parent_id)
          return true if parent_id.nil? || parent_id.zero?

          packages.any? { |p| p.package_id == parent_id }
        end
      end
    end
  end
end
