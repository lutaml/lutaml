# frozen_string_literal: true

require_relative "validation_result"
require_relative "validation_error"

module Lutaml
  module Xsd
    module Validation
      # ResultCollector aggregates validation results
      #
      # This class collects validation errors, warnings, and info messages
      # during the validation process and provides methods to aggregate
      # them into a final ValidationResult.
      #
      # @example Collect validation results
      #   collector = ResultCollector.new(config)
      #   collector.add_error(error1)
      #   collector.add_warning(warning1)
      #   result = collector.to_result
      class ResultCollector
        # @return [ValidationConfiguration] The validation configuration
        attr_reader :config

        # @return [Array<ValidationError>] Collection of errors
        attr_reader :errors

        # @return [Array<ValidationError>] Collection of warnings
        attr_reader :warnings

        # @return [Array<ValidationError>] Collection of info messages
        attr_reader :infos

        # Initialize a new ResultCollector
        #
        # @param config [ValidationConfiguration] The validation configuration
        def initialize(config)
          @config = config
          @errors = []
          @warnings = []
          @infos = []
        end

        # Add an error to the collection
        #
        # @param error [ValidationError] The error to add
        # @return [void]
        #
        # @raise [ArgumentError] if error is not a ValidationError
        def add_error(error)
          validate_error!(error)
          return if should_skip_error?(error)

          @errors << error

          # Stop collecting if configured to stop on first error
          raise StopValidationError if stop_on_first_error? && has_errors?
        end

        # Add a warning to the collection
        #
        # @param warning [ValidationError] The warning to add
        # @return [void]
        #
        # @raise [ArgumentError] if warning is not a ValidationError
        def add_warning(warning)
          validate_error!(warning)
          return if should_skip_error?(warning)

          @warnings << warning
        end

        # Add an info message to the collection
        #
        # @param info [ValidationError] The info message to add
        # @return [void]
        #
        # @raise [ArgumentError] if info is not a ValidationError
        def add_info(info)
          validate_error!(info)
          return if should_skip_error?(info)

          @infos << info
        end

        # Add an issue based on its severity
        #
        # Automatically routes the issue to the appropriate collection
        # based on its severity level.
        #
        # @param issue [ValidationError] The issue to add
        # @return [void]
        def add_issue(issue)
          case issue.severity
          when :error then add_error(issue)
          when :warning then add_warning(issue)
          when :info then add_info(issue)
          else
            raise ArgumentError, "Invalid severity: #{issue.severity}"
          end
        end

        # Check if there are any errors
        #
        # @return [Boolean]
        def has_errors?
          @errors.any?
        end

        # Check if there are any warnings
        #
        # @return [Boolean]
        def has_warnings?
          @warnings.any?
        end

        # Check if there are any info messages
        #
        # @return [Boolean]
        def has_infos?
          @infos.any?
        end

        # Check if there are any issues at all
        #
        # @return [Boolean]
        def has_issues?
          has_errors? || has_warnings? || has_infos?
        end

        # Get total count of all issues
        #
        # @return [Integer]
        def total_count
          @errors.size + @warnings.size + @infos.size
        end

        # Get count by severity
        #
        # @return [Hash<Symbol, Integer>]
        def count_by_severity
          {
            errors: @errors.size,
            warnings: @warnings.size,
            infos: @infos.size,
          }
        end

        # Convert collected results to a ValidationResult
        #
        # @return [ValidationResult]
        def to_result
          ValidationResult.new(
            valid: !has_errors?,
            errors: @errors.dup,
            warnings: @warnings.dup,
            infos: @infos.dup,
          )
        end

        # Clear all collected results
        #
        # @return [void]
        def clear
          @errors.clear
          @warnings.clear
          @infos.clear
        end

        # Get all issues (errors + warnings + infos)
        #
        # @return [Array<ValidationError>]
        def all_issues
          @errors + @warnings + @infos
        end

        # Filter issues by code
        #
        # @param code [String] Error code to filter by
        # @return [Array<ValidationError>]
        def issues_with_code(code)
          all_issues.select { |issue| issue.code == code }
        end

        # Filter issues by location
        #
        # @param location [String] Location to filter by
        # @return [Array<ValidationError>]
        def issues_at_location(location)
          all_issues.select { |issue| issue.location == location }
        end

        # Convert to hash representation
        #
        # @return [Hash]
        def to_h
          {
            errors: @errors.map(&:to_h),
            warnings: @warnings.map(&:to_h),
            infos: @infos.map(&:to_h),
            counts: count_by_severity,
            valid: !has_errors?,
          }
        end

        private

        # Validate that the error is a ValidationError
        #
        # @param error [Object] The object to validate
        # @raise [ArgumentError] if not a ValidationError
        def validate_error!(error)
          return if error.is_a?(ValidationError)

          raise ArgumentError,
                "Expected ValidationError, got #{error.class}"
        end

        # Check if error should be skipped based on max errors limit
        #
        # @param error [ValidationError] The error
        # @return [Boolean]
        def should_skip_error?(_error)
          return false unless @config.max_errors

          total_count >= @config.max_errors
        end

        # Check if should stop on first error
        #
        # @return [Boolean]
        def stop_on_first_error?
          @config.stop_on_first_error?
        end

        # Exception raised to stop validation early
        class StopValidationError < StandardError; end
      end
    end
  end
end
