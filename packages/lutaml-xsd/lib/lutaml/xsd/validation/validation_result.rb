# frozen_string_literal: true

module Lutaml
  module Xsd
    module Validation
      # ValidationResult holds the outcome of XML validation
      #
      # This class encapsulates the complete result of validating an XML
      # document against XSD schemas. It tracks whether validation succeeded,
      # collects all errors and warnings, and provides methods for
      # querying and formatting the results.
      #
      # @example Check if validation succeeded
      #   result = validator.validate(xml_content)
      #   if result.valid?
      #     puts "Validation successful!"
      #   end
      #
      # @example Access errors
      #   result.errors.each do |error|
      #     puts "#{error.code}: #{error.message} at #{error.location}"
      #   end
      #
      # @example Get formatted summary
      #   puts result.summary
      class ValidationResult
        attr_reader :errors, :warnings, :infos

        # Initialize a new ValidationResult
        #
        # @param valid [Boolean] Whether validation succeeded
        # @param errors [Array<ValidationError>] Collection of validation errors
        # @param warnings [Array<ValidationError>] Collection of warnings
        # @param infos [Array<ValidationError>] Collection of info messages
        def initialize(valid:, errors: [], warnings: [], infos: [])
          @valid = valid
          @errors = errors
          @warnings = warnings
          @infos = infos
        end

        # Check if validation succeeded
        #
        # @return [Boolean] true if no errors were found
        def valid?
          @valid && @errors.empty?
        end

        # Check if validation failed
        #
        # @return [Boolean] true if errors were found
        def invalid?
          !valid?
        end

        # Get total number of errors
        #
        # @return [Integer]
        def error_count
          @errors.size
        end

        # Get total number of warnings
        #
        # @return [Integer]
        def warning_count
          @warnings.size
        end

        # Get total number of issues (errors + warnings)
        #
        # @return [Integer]
        def total_issues
          error_count + warning_count
        end

        # Check if there are any errors
        #
        # @return [Boolean]
        def errors?
          @errors.any?
        end

        # Check if there are any warnings
        #
        # @return [Boolean]
        def warnings?
          @warnings.any?
        end

        # Get errors by severity level
        #
        # @param severity [Symbol] Severity level (:error, :warning, :info)
        # @return [Array<ValidationError>]
        def errors_by_severity(severity)
          all_issues.select { |issue| issue.severity == severity }
        end

        # Get all issues (errors and warnings combined)
        #
        # @return [Array<ValidationError>]
        def all_issues
          @errors + @warnings
        end

        # Get errors grouped by code
        #
        # @return [Hash<String, Array<ValidationError>>]
        def errors_by_code
          @errors.group_by(&:code)
        end

        # Get errors for a specific location
        #
        # @param location [String] XPath or line number
        # @return [Array<ValidationError>]
        def errors_at(location)
          @errors.select { |e| e.location == location }
        end

        # Generate a human-readable summary
        #
        # @return [String]
        def summary
          if valid?
            "✓ Validation successful (#{warning_count} warnings)"
          else
            "✗ Validation failed: #{error_count} errors, " \
              "#{warning_count} warnings"
          end
        end

        # Convert result to hash representation
        #
        # @return [Hash]
        def to_h
          {
            valid: valid?,
            error_count: error_count,
            warning_count: warning_count,
            errors: @errors.map(&:to_h),
            warnings: @warnings.map(&:to_h),
          }
        end

        # Convert result to JSON
        #
        # @return [String]
        def to_json(*)
          require "json"
          to_h.to_json(*)
        end

        # Generate detailed report
        #
        # @param include_warnings [Boolean] Whether to include warnings
        # @return [String]
        def detailed_report(include_warnings: true)
          lines = []
          lines << summary
          lines << ""

          if @errors.any?
            lines << "Errors:"
            @errors.each_with_index do |error, index|
              lines << "  #{index + 1}. #{error.detailed_message}"
            end
            lines << ""
          end

          if include_warnings && @warnings.any?
            lines << "Warnings:"
            @warnings.each_with_index do |warning, index|
              lines << "  #{index + 1}. #{warning.detailed_message}"
            end
            lines << ""
          end

          lines.join("\n")
        end

        # Check if result has specific error code
        #
        # @param code [String] Error code to check
        # @return [Boolean]
        def has_error_code?(code)
          @errors.any? { |e| e.code == code }
        end

        # Get first error
        #
        # @return [ValidationError, nil]
        def first_error
          @errors.first
        end

        # Get first warning
        #
        # @return [ValidationError, nil]
        def first_warning
          @warnings.first
        end
      end
    end
  end
end
