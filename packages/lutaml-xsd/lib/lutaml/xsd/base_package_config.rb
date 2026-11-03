# frozen_string_literal: true

require_relative "namespace_uri_remapping"
require_relative "validation_error"
require_relative "validation_result"

module Lutaml
  module Xsd
    # Configuration for a single base package with conflict resolution settings
    class BasePackageConfig < Lutaml::Model::Serializable
      attribute :package, :string
      attribute :priority, :integer, default: -> { 0 }
      attribute :conflict_resolution, :string, default: -> { "error" }
      attribute :namespace_remapping, NamespaceUriRemapping, collection: true
      attribute :exclude_schemas, :string, collection: true
      attribute :include_only_schemas, :string, collection: true

      yaml do
        map "package", to: :package
        map "priority", to: :priority
        map "conflict_resolution", to: :conflict_resolution
        map "namespace_remapping", to: :namespace_remapping
        map "exclude_schemas", to: :exclude_schemas
        map "include_only_schemas", to: :include_only_schemas
      end

      # Validate configuration
      # @return [ValidationResult]
      def validate
        errors = []

        # Package path validation
        if package.nil? || package.empty?
          errors << ValidationError.create(
            field: :package,
            message: "Package path is required",
            constraint: "presence",
          )
        end

        # Conflict resolution validation
        valid_strategies = ["keep", "override", "error"]
        unless valid_strategies.include?(conflict_resolution)
          errors << ValidationError.create(
            field: :conflict_resolution,
            message: "Invalid conflict resolution strategy",
            value: conflict_resolution,
            constraint: "inclusion: #{valid_strategies.join(', ')}",
          )
        end

        # Priority validation
        if priority.negative?
          errors << ValidationError.create(
            field: :priority,
            message: "Priority must be non-negative",
            value: priority,
            constraint: ">= 0",
          )
        end

        # Namespace remapping validation
        namespace_remapping&.each_with_index do |remap, idx|
          remap_result = remap.validate
          if remap_result.invalid?
            remap_result.errors.each do |error|
              errors << ValidationError.create(
                field: "namespace_remapping[#{idx}].#{error.field}",
                message: error.message,
                value: error.value,
                constraint: error.constraint,
              )
            end
          end
        end

        errors.empty? ? ValidationResult.success : ValidationResult.failure(errors)
      end

      # Check if configuration is valid
      # @return [Boolean]
      def valid?
        validate.valid?
      end

      # Raise error if invalid
      # @raise [ValidationFailedError]
      def validate!
        validate.validate!
      end

      # Apply schema filtering
      # @param schema_path [String] Schema file path
      # @return [Boolean] True if schema should be included
      def include_schema?(schema_path)
        return false if exclude_schemas&.any? && matches_patterns?(schema_path,
                                                                   exclude_schemas)
        if include_only_schemas&.any?
          return matches_patterns?(schema_path,
                                   include_only_schemas)
        end

        true
      end

      private

      def matches_patterns?(path, patterns)
        patterns.any? { |pattern| File.fnmatch?(pattern, path, File::FNM_PATHNAME) }
      end
    end
  end
end
