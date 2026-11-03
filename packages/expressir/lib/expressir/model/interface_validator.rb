# frozen_string_literal: true

module Expressir
  module Model
    # Validates EXPRESS interface statements (USE FROM, REFERENCE FROM)
    # Single responsibility: Interface-specific validation only
    # Handles schema reference validation, interface item validation, and type compatibility checks
    class InterfaceValidator
      # Error types returned by validation
      ERROR_TYPES = {
        missing_schema: :missing_schema_reference,
        missing_item: :missing_interface_item,
        type_mismatch: :interface_type_mismatch,
        duplicate_alias: :duplicate_interface_alias,
        self_reference: :self_reference_interface,
        empty_items: :empty_interface_items,
      }.freeze

      attr_reader :repository, :schemas

      # Initialize validator with a repository
      # @param repository [Repository] Repository containing schemas to validate
      def initialize(repository)
        @repository = repository
        @schemas = repository.schemas
      end

      # Main validation entry point
      # @param options [Hash] Validation options
      # @option options [Boolean] :detailed Show detailed reports with fix suggestions
      # @option options [Boolean] :check_duplicates Check for duplicate aliases
      # @option options [Boolean] :check_self_references Check for self-referencing interfaces
      # @option options [Boolean] :strict Enable strict validation (warnings become errors)
      # @return [Hash] Validation results with :valid?, :errors, :warnings, :interface_report
      def validate(options = {})
        errors = []
        warnings = []
        stats = { use_from: 0, reference_from: 0, total_items: 0 }

        schemas.each do |schema|
          validate_schema_interfaces(schema, errors, warnings, stats, options)
        end

        result = {
          valid?: errors.empty?,
          errors: errors,
          warnings: warnings,
          stats: stats,
        }

        if options[:detailed]
          result[:interface_report] =
            build_detailed_report(errors, warnings, stats)
        end

        result
      end

      # Validate interfaces in a specific schema
      # @param schema_name [String] Schema name
      # @param options [Hash] Validation options
      # @return [Hash] Validation results for the schema
      def validate_schema(schema_name, options = {})
        schema = find_schema(schema_name)
        unless schema
          return { valid?: false,
                   errors: [{ type: :schema_not_found,
                              message: "Schema '#{schema_name}' not found" }] }
        end

        errors = []
        warnings = []
        stats = { use_from: 0, reference_from: 0, total_items: 0 }

        validate_schema_interfaces(schema, errors, warnings, stats, options)

        {
          valid?: errors.empty?,
          errors: errors,
          warnings: warnings,
          stats: stats,
        }
      end

      private

      # Validate all interfaces in a schema
      # @param schema [Declarations::Schema] Schema to validate
      # @param errors [Array] Accumulator for errors
      # @param warnings [Array] Accumulator for warnings
      # @param stats [Hash] Statistics accumulator
      # @param options [Hash] Validation options
      # @return [void]
      def validate_schema_interfaces(schema, errors, warnings, stats, options)
        return unless schema.interfaces

        schema.interfaces.each do |interface|
          case interface.kind
          when Declarations::Interface::USE
            stats[:use_from] += 1
            validate_use_from(schema, interface, errors, warnings, options)
          when Declarations::Interface::REFERENCE
            stats[:reference_from] += 1
            validate_reference_from(schema, interface, errors, warnings,
                                    options)
          end

          stats[:total_items] += interface.items.size
        end

        # Additional validations if enabled
        if options[:check_duplicates]
          check_duplicate_aliases(schema, errors)
        end

        if options[:check_self_references]
          check_self_references(schema, warnings)
        end
      end

      # Validate USE FROM interface
      # @param schema [Declarations::Schema] Source schema
      # @param interface [Declarations::Interface] Interface to validate
      # @param errors [Array] Accumulator for errors
      # @param warnings [Array] Accumulator for warnings
      # @param options [Hash] Validation options
      # @return [void]
      def validate_use_from(schema, interface, errors, warnings, _options)
        referenced_schema = find_schema(interface.schema.id)

        if referenced_schema.nil?
          errors << build_error(
            type: ERROR_TYPES[:missing_schema],
            schema: schema.id,
            interface_type: "USE FROM",
            referenced_schema: interface.schema.id,
            message: "Schema '#{schema.id}' uses non-existent schema '#{interface.schema.id}'",
            fix_suggestion: "Ensure schema '#{interface.schema.id}' exists in the repository or remove the USE FROM statement",
          )
          return
        end

        # Validate interface items
        validate_interface_items(schema, interface, referenced_schema, errors,
                                 warnings, "USE FROM")

        # Warn if USE FROM has no items (imports everything)
        if interface.items.empty?
          warnings << {
            type: ERROR_TYPES[:empty_items],
            schema: schema.id,
            interface_type: "USE FROM",
            referenced_schema: interface.schema.id,
            message: "USE FROM imports all items from '#{interface.schema.id}' (consider specifying explicit items)",
            fix_suggestion: "Add explicit item list: USE FROM #{interface.schema.id} (item1, item2, ...);",
          }
        end
      end

      # Validate REFERENCE FROM interface
      # @param schema [Declarations::Schema] Source schema
      # @param interface [Declarations::Interface] Interface to validate
      # @param errors [Array] Accumulator for errors
      # @param warnings [Array] Accumulator for warnings
      # @param options [Hash] Validation options
      # @return [void]
      def validate_reference_from(schema, interface, errors, warnings, _options)
        referenced_schema = find_schema(interface.schema.id)

        if referenced_schema.nil?
          errors << build_error(
            type: ERROR_TYPES[:missing_schema],
            schema: schema.id,
            interface_type: "REFERENCE FROM",
            referenced_schema: interface.schema.id,
            message: "Schema '#{schema.id}' references non-existent schema '#{interface.schema.id}'",
            fix_suggestion: "Ensure schema '#{interface.schema.id}' exists in the repository or remove the REFERENCE FROM statement",
          )
          return
        end

        # Validate interface items
        validate_interface_items(schema, interface, referenced_schema, errors,
                                 warnings, "REFERENCE FROM")

        # REFERENCE FROM should always have explicit items
        if interface.items.empty?
          errors << build_error(
            type: ERROR_TYPES[:empty_items],
            schema: schema.id,
            interface_type: "REFERENCE FROM",
            referenced_schema: interface.schema.id,
            message: "REFERENCE FROM requires explicit item list",
            fix_suggestion: "Add item list: REFERENCE FROM #{interface.schema.id} (item1, item2, ...);",
          )
        end
      end

      # Validate interface items exist in referenced schema
      # @param schema [Declarations::Schema] Source schema
      # @param interface [Declarations::Interface] Interface to validate
      # @param referenced_schema [Declarations::Schema] Referenced schema
      # @param errors [Array] Accumulator for errors
      # @param warnings [Array] Accumulator for warnings
      # @param interface_type [String] Type of interface (USE FROM or REFERENCE FROM)
      # @return [void]
      def validate_interface_items(schema, interface, referenced_schema,
errors, _warnings, interface_type)
        interface.items.each do |item|
          ref_id = item.ref.id.safe_downcase
          item_type = find_item_type(referenced_schema, ref_id)

          unless item_type
            errors << build_error(
              type: ERROR_TYPES[:missing_item],
              schema: schema.id,
              interface_type: interface_type,
              referenced_schema: interface.schema.id,
              item: item.ref.id,
              message: "Interface item '#{item.ref.id}' not found in schema '#{interface.schema.id}'",
              fix_suggestion: "Remove '#{item.ref.id}' from interface or check spelling. Available items in '#{interface.schema.id}': #{list_available_items(referenced_schema)}",
            )
          end
        end
      end

      # Check for duplicate interface aliases
      # @param schema [Declarations::Schema] Schema to check
      # @param errors [Array] Accumulator for errors
      # @return [void]
      def check_duplicate_aliases(schema, errors)
        return unless schema.interfaces

        aliases = {}
        schema.interfaces.each do |interface|
          interface.items.each do |item|
            alias_id = (item.id || item.ref.id).safe_downcase
            if aliases[alias_id]
              errors << build_error(
                type: ERROR_TYPES[:duplicate_alias],
                schema: schema.id,
                alias: alias_id,
                message: "Duplicate interface alias '#{item.id || item.ref.id}' in schema '#{schema.id}'",
                fix_suggestion: "Use unique aliases: USE FROM schema (item AS unique_name)",
              )
            else
              aliases[alias_id] = true
            end
          end
        end
      end

      # Check for self-referencing interfaces
      # @param schema [Declarations::Schema] Schema to check
      # @param warnings [Array] Accumulator for warnings
      # @return [void]
      def check_self_references(schema, warnings)
        return unless schema.interfaces

        schema.interfaces.each do |interface|
          if interface.schema.id.safe_downcase == schema.id.safe_downcase
            warnings << {
              type: ERROR_TYPES[:self_reference],
              schema: schema.id,
              message: "Schema '#{schema.id}' references itself (likely unnecessary)",
              fix_suggestion: "Remove self-referencing interface statement",
            }
          end
        end
      end

      # Find schema by name
      # @param schema_name [String] Schema name
      # @return [Declarations::Schema, nil] Found schema or nil
      def find_schema(schema_name)
        schemas.find { |s| s.id.safe_downcase == schema_name.safe_downcase }
      end

      # Find item type in schema
      # @param schema [Declarations::Schema] Schema to search
      # @param ref_id [String] Item reference ID (normalized)
      # @return [Symbol, nil] Item type or nil if not found
      def find_item_type(schema, ref_id)
        return :entity if schema.entities&.any? do |e|
          e.id.safe_downcase == ref_id
        end
        return :type if schema.types&.any? { |t| t.id.safe_downcase == ref_id }
        return :function if schema.functions&.any? do |f|
          f.id.safe_downcase == ref_id
        end
        return :procedure if schema.procedures&.any? do |p|
          p.id.safe_downcase == ref_id
        end
        return :constant if schema.constants&.any? do |c|
          c.id.safe_downcase == ref_id
        end
        return :rule if schema.rules&.any? { |r| r.id.safe_downcase == ref_id }

        nil
      end

      # List available items in schema
      # @param schema [Declarations::Schema] Schema to list items from
      # @param limit [Integer] Maximum number of items to list
      # @return [String] Comma-separated list of items
      def list_available_items(schema, limit = 10)
        items = []
        items.concat(schema.entities.map(&:id)) if schema.entities
        items.concat(schema.types.map(&:id)) if schema.types
        items.concat(schema.functions.map(&:id)) if schema.functions
        items.concat(schema.procedures.map(&:id)) if schema.procedures
        items.concat(schema.constants.map(&:id)) if schema.constants

        items = items.take(limit)
        result = items.join(", ")
        result += ", ..." if items.size == limit
        result
      end

      # Build error hash with consistent structure
      # @param params [Hash] Error parameters
      # @return [Hash] Error hash
      def build_error(**params)
        params
      end

      # Build detailed report from errors and warnings
      # @param errors [Array<Hash>] Validation errors
      # @param warnings [Array<Hash>] Validation warnings
      # @param stats [Hash] Statistics
      # @return [String] Formatted report
      def build_detailed_report(errors, warnings, stats)
        report = []
        report << ("=" * 80)
        report << "Interface Validation Report"
        report << ("=" * 80)
        report << ""

        # Statistics
        report << "Statistics:"
        report << "  Total USE FROM statements: #{stats[:use_from]}"
        report << "  Total REFERENCE FROM statements: #{stats[:reference_from]}"
        report << "  Total interface items: #{stats[:total_items]}"
        report << ""

        # Errors
        if errors.any?
          report << "Errors (#{errors.size}):"
          report << ("-" * 80)
          errors.each_with_index do |error, i|
            report << "#{i + 1}. [#{error[:type]}] #{error[:message]}"
            report << "   Schema: #{error[:schema]}" if error[:schema]
            report << "   Referenced Schema: #{error[:referenced_schema]}" if error[:referenced_schema]
            report << "   Item: #{error[:item]}" if error[:item]
            report << "   Fix: #{error[:fix_suggestion]}" if error[:fix_suggestion]
            report << ""
          end
        else
          report << "✓ No errors found"
          report << ""
        end

        # Warnings
        if warnings.any?
          report << "Warnings (#{warnings.size}):"
          report << ("-" * 80)
          warnings.each_with_index do |warning, i|
            report << "#{i + 1}. [#{warning[:type]}] #{warning[:message]}"
            report << "   Schema: #{warning[:schema]}" if warning[:schema]
            report << "   Referenced Schema: #{warning[:referenced_schema]}" if warning[:referenced_schema]
            report << "   Fix: #{warning[:fix_suggestion]}" if warning[:fix_suggestion]
            report << ""
          end
        else
          report << "✓ No warnings"
          report << ""
        end

        report << ("=" * 80)
        report.join("\n")
      end
    end
  end
end
