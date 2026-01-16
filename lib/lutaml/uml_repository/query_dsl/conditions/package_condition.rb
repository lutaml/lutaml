# frozen_string_literal: true

require_relative "base_condition"
require_relative "../../../uml/package_path"

module Lutaml
  module UmlRepository
    module QueryDSL
      module Conditions
        # Package-based condition for filtering by package membership
        #
        # Filters results based on package path, with support for
        # recursive (descendant) matching.
        #
        # @example Filter by exact package
        #   condition = PackageCondition.new(
        #   "ModelRoot::i-UR", recursive: false)
        #   filtered = condition.apply(classes)
        #
        # @example Filter by package and descendants
        #   condition = PackageCondition.new("ModelRoot::i-UR", recursive: true)
        #   filtered = condition.apply(classes)
        class PackageCondition < BaseCondition
          # Initialize with package path and recursion setting
          #
          # @param package_path [String, PackagePath]
          # The package path to filter by
          # @param recursive [Boolean] Whether to include descendants
          def initialize(package_path, recursive: false)
            super()
            @package_path = if package_path.is_a?(PackagePath)
                              package_path
                            else
                              PackagePath.new(package_path)
                            end
            @recursive = recursive
          end

          # Apply package-based filtering to results
          #
          # @param results [Array] The collection to filter
          # @return [Array] Objects in the specified package
          def apply(results)
            results.select do |obj|
              matches_package?(obj)
            end
          end

          private

          # Check if object matches package condition
          #
          # @param obj [Object] The object to check
          # @return [Boolean] true if object is in target package
          def matches_package?(obj)
            obj_package_path = extract_package_path(obj)
            return false unless obj_package_path

            if @recursive
              obj_package_path.starts_with?(@package_path)
            else
              obj_package_path == @package_path
            end
          end

          # Extract package path from object
          #
          # @param obj [Object] The object to extract path from
          # @return [PackagePath, nil] The object's package path
          def extract_package_path(obj)
            return nil unless obj.respond_to?(:package_path)

            path = obj.package_path
            return nil unless path

            path.is_a?(PackagePath) ? path : PackagePath.new(path)
          rescue ArgumentError
            nil
          end
        end
      end
    end
  end
end
