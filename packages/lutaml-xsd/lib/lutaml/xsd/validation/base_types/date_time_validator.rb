# frozen_string_literal: true

require_relative "base_type_validator"

module Lutaml
  module Xsd
    module Validation
      module BaseTypes
        # Validates XSD dateTime type
        #
        # The dateTime type represents a specific instant in time in the
        # format: YYYY-MM-DDTHH:MM:SS with optional timezone and fractional
        # seconds.
        #
        # @example Validating dateTime values
        #   validator = DateTimeValidator.new
        #   validator.valid?("2024-01-15T14:30:00")       # => true
        #   validator.valid?("2024-01-15T14:30:00Z")      # => true
        #   validator.valid?("2024-01-15T14:30:00+05:30") # => true
        #   validator.valid?("2024-01-15T14:30:00.123Z")  # => true
        #   validator.valid?("2024-01-15")                # => false
        #
        class DateTimeValidator < BaseTypeValidator
          # ISO 8601 dateTime pattern
          DATETIME_PATTERN = /^
            -?\d{4}-\d{2}-\d{2}     # Date part: YYYY-MM-DD
            T                        # T separator
            \d{2}:\d{2}:\d{2}       # Time part: HH:MM:SS
            (\.\d+)?                 # Optional fractional seconds
            (Z|[+-]\d{2}:\d{2})?    # Optional timezone
          $/x

          # Validate value is a valid dateTime
          #
          # @param value [Object] The value to validate
          # @return [Boolean] true if value is a valid ISO 8601 dateTime
          def valid?(value)
            return false if value.nil?
            return true if value.is_a?(DateTime) || value.is_a?(Time)

            str = to_string(value).strip
            return false unless str.match?(DATETIME_PATTERN)

            # Attempt to parse with Ruby's DateTime
            DateTime.iso8601(str)
            true
          rescue ArgumentError, TypeError
            false
          end

          # Generate error message for invalid dateTime
          #
          # @param value [Object] The invalid value
          # @return [String] Error message
          def error_message(value)
            "Value '#{value}' is not a valid dateTime. " \
              "Expected format: YYYY-MM-DDTHH:MM:SS[.sss][Z|(+|-)HH:MM]"
          end
        end
      end
    end
  end
end
