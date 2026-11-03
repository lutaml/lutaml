# frozen_string_literal: true

require_relative "base_type_validator"

module Lutaml
  module Xsd
    module Validation
      module BaseTypes
        # Validates XSD date type
        #
        # The date type represents a calendar date in the format: YYYY-MM-DD
        # with optional timezone.
        #
        # @example Validating date values
        #   validator = DateValidator.new
        #   validator.valid?("2024-01-15")       # => true
        #   validator.valid?("2024-01-15Z")      # => true
        #   validator.valid?("2024-01-15+05:30") # => true
        #   validator.valid?("2024-1-5")         # => false (must be padded)
        #   validator.valid?("01-15-2024")       # => false (wrong format)
        #
        class DateValidator < BaseTypeValidator
          # ISO 8601 date pattern
          DATE_PATTERN = /^
            -?\d{4}-\d{2}-\d{2}     # Date part: YYYY-MM-DD
            (Z|[+-]\d{2}:\d{2})?    # Optional timezone
          $/x

          # Validate value is a valid date
          #
          # @param value [Object] The value to validate
          # @return [Boolean] true if value is a valid ISO 8601 date
          def valid?(value)
            return false if value.nil?
            return true if value.is_a?(Date)

            str = to_string(value).strip
            return false unless str.match?(DATE_PATTERN)

            # Extract date part (before timezone)
            date_part = str.split(/[Z+-]/)[0]

            # Attempt to parse with Ruby's Date
            Date.parse(date_part)
            true
          rescue ArgumentError, TypeError
            false
          end

          # Generate error message for invalid date
          #
          # @param value [Object] The invalid value
          # @return [String] Error message
          def error_message(value)
            "Value '#{value}' is not a valid date. " \
              "Expected format: YYYY-MM-DD[Z|(+|-)HH:MM]"
          end
        end
      end
    end
  end
end
