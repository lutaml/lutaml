# frozen_string_literal: true

module Expressir
  module Model
    # Validator for repository consistency checks
    # Handles schema reference validation, interface item validation,
    # circular dependency detection, and unused schema warnings
    # Coordinates with InterfaceValidator for detailed interface validation
    class RepositoryValidator
      # Initialize validator with schemas and reference index
      # @param schemas [Array<Declarations::Schema>] Schemas to validate
      # @param reference_index [Indexes::ReferenceIndex] Reference index for dependency tracking
      def initialize(schemas, reference_index)
        @schemas = schemas
        @reference_index = reference_index
      end

      # Validate repository consistency
      # @param strict [Boolean] Enable strict validation (unused schemas)
      # @param check_interfaces [Boolean] Enable detailed interface validation
      # @param check_completeness [Boolean] Check for schema completeness
      # @param detailed [Boolean] Generate detailed reports
      # @param check_duplicates [Boolean] Check for duplicate interface aliases
      # @param check_self_references [Boolean] Check for self-referencing interfaces
      # @return [Hash] Validation results with :valid?, :errors, :warnings
      def validate(
        strict: false,
        check_interfaces: false,
        check_completeness: false,
        detailed: false,
        check_duplicates: false,
        check_self_references: false
      )
        errors = []
        warnings = []

        # Existing basic validations (always run)
        validate_schema_references(errors)
        validate_interface_items(errors)
        detect_circular_dependencies(warnings)

        if strict
          detect_unused_schemas(warnings)
        end

        # NEW: Detailed interface validation
        interface_result = nil
        if check_interfaces
          begin
            interface_result = run_interface_validation(
              detailed: detailed,
              check_duplicates: check_duplicates,
              check_self_references: check_self_references,
            )

            # Merge results, avoiding duplicates
            merge_validation_results(errors, warnings, interface_result)
          rescue StandardError => e
            # If interface validation fails, add a warning instead of crashing
            warnings << {
              type: :interface_validation_error,
              message: "Could not perform detailed interface validation: #{e.message}",
            }
          end
        end

        # NEW: Completeness checks
        if check_completeness
          check_schema_completeness(warnings)
        end

        result = {
          valid?: errors.empty?,
          errors: errors,
          warnings: warnings,
        }

        # Include detailed report if requested and available
        if detailed && interface_result && interface_result[:interface_report]
          result[:interface_report] = interface_result[:interface_report]
        end

        result
      end

      private

      # Run InterfaceValidator
      # @param options [Hash] Validation options
      # @return [Hash] Interface validation results
      def run_interface_validation(options = {})
        # Build temporary repository for InterfaceValidator
        repository = build_temporary_repository
        interface_validator = InterfaceValidator.new(repository)
        interface_validator.validate(options)
      end

      # Build a temporary repository from schemas
      # @return [Repository] Temporary repository
      def build_temporary_repository
        # Find the parent repository if schemas have one
        repo = @schemas.first&.parent
        return repo if repo.is_a?(Repository)

        # Create temporary repository
        temp_repo = Repository.new
        temp_repo.schemas = @schemas
        temp_repo
      end

      # Merge interface validation results, avoiding duplicates
      # @param errors [Array] Existing errors
      # @param warnings [Array] Existing warnings
      # @param interface_result [Hash] Interface validation results
      # @return [void]
      def merge_validation_results(errors, warnings, interface_result)
        # Add interface errors, avoiding duplicates
        interface_result[:errors].each do |error|
          # Check if this error type already exists for the same schema/item
          unless errors.any? { |e| error_matches?(e, error) }
            errors << error
          end
        end

        # Add interface warnings, avoiding duplicates
        interface_result[:warnings].each do |warning|
          unless warnings.any? { |w| warning_matches?(w, warning) }
            warnings << warning
          end
        end
      end

      # Check if two errors match (to avoid duplicates)
      # @param e1 [Hash] First error
      # @param e2 [Hash] Second error
      # @return [Boolean] True if errors match
      def error_matches?(e1, e2)
        e1[:type] == e2[:type] &&
          e1[:schema] == e2[:schema] &&
          e1[:referenced_schema] == e2[:referenced_schema] &&
          e1[:item] == e2[:item]
      end

      # Check if two warnings match (to avoid duplicates)
      # @param w1 [Hash] First warning
      # @param w2 [Hash] Second warning
      # @return [Boolean] True if warnings match
      def warning_matches?(w1, w2)
        w1[:type] == w2[:type] &&
          w1[:schema] == w2[:schema]
      end

      # Check schema completeness
      # @param warnings [Array] Accumulator for warnings
      # @return [void]
      def check_schema_completeness(warnings)
        @schemas.each do |schema|
          # Warn if schema has no entities
          if schema.entities.nil? || schema.entities.empty?
            warnings << {
              type: :empty_schema,
              schema: schema.id,
              message: "Schema '#{schema.id}' has no entities defined",
            }
          end

          # Warn if schema has entities but no types
          if schema.entities&.any? && (schema.types.nil? || schema.types.empty?)
            warnings << {
              type: :no_types,
              schema: schema.id,
              message: "Schema '#{schema.id}' has entities but no types defined (common but may indicate incomplete schema)",
            }
          end
        end
      end

      # Validate that all referenced schemas exist
      # @param errors [Array] Accumulator for errors
      # @return [void]
      def validate_schema_references(errors)
        @schemas.each do |schema|
          next unless schema.interfaces

          schema.interfaces.each do |interface|
            referenced_schema = find_schema(interface.schema.id)

            if referenced_schema.nil?
              errors << {
                type: :missing_schema_reference,
                schema: schema.id,
                interface_type: interface.kind,
                referenced_schema: interface.schema.id,
                message: "Schema '#{schema.id}' references non-existent schema '#{interface.schema.id}'",
              }
            end
          end
        end
      end

      # Validate that all interface items exist in referenced schemas
      # @param errors [Array] Accumulator for errors
      # @return [void]
      def validate_interface_items(errors)
        @schemas.each do |schema|
          next unless schema.interfaces

          schema.interfaces.each do |interface|
            referenced_schema = find_schema(interface.schema.id)
            next if referenced_schema.nil? # Already caught by validate_schema_references

            interface.items.each do |item|
              ref_id = item.ref.id.safe_downcase
              found = item_exists_in_schema?(referenced_schema, ref_id)

              unless found
                errors << {
                  type: :missing_interface_item,
                  schema: schema.id,
                  interface_type: interface.kind,
                  referenced_schema: interface.schema.id,
                  item: item.ref.id,
                  message: "Interface item '#{item.ref.id}' not found in schema '#{interface.schema.id}'",
                }
              end
            end
          end
        end
      end

      # Detect circular dependencies using the reference index
      # Note: Circular dependencies are valid in EXPRESS (mutual USE FROM)
      # @param warnings [Array] Accumulator for warnings
      # @return [void]
      def detect_circular_dependencies(warnings)
        cycles = @reference_index.detect_circular_dependencies

        cycles.each do |cycle|
          warnings << {
            type: :circular_dependency,
            cycle: cycle,
            message: "Circular dependency (valid in EXPRESS): #{cycle.join(' -> ')}",
          }
        end
      end

      # Detect unused schemas in strict mode
      # @param warnings [Array] Accumulator for warnings
      # @return [void]
      def detect_unused_schemas(warnings)
        # Don't warn for single schema repositories
        return if @schemas.size == 1

        used_schemas = Set.new
        @schemas.each do |schema|
          next unless schema.interfaces

          schema.interfaces.each do |interface|
            used_schemas << interface.schema.id.safe_downcase
          end

          schema_id = schema.id.safe_downcase
          next if used_schemas.include?(schema_id)

          warnings << {
            type: :unused_schema,
            schema: schema.id,
            message: "Schema '#{schema.id}' is not referenced by any other schema",
          }
        end
      end

      # Find schema by name
      # @param schema_name [String] Schema name
      # @return [Declarations::Schema, nil] Found schema or nil
      def find_schema(schema_name)
        @schemas.find { |s| s.id.safe_downcase == schema_name.safe_downcase }
      end

      # Check if an item exists in a schema
      # @param schema [Declarations::Schema] Schema to search
      # @param ref_id [String] Item reference ID (normalized)
      # @return [Boolean] True if item exists
      def item_exists_in_schema?(schema, ref_id)
        schema.entities&.any? { |e| e.id.safe_downcase == ref_id } ||
          schema.types&.any? { |t| t.id.safe_downcase == ref_id } ||
          schema.functions&.any? { |f| f.id.safe_downcase == ref_id } ||
          schema.procedures&.any? { |p| p.id.safe_downcase == ref_id } ||
          schema.constants&.any? { |c| c.id.safe_downcase == ref_id }
      end
    end
  end
end
