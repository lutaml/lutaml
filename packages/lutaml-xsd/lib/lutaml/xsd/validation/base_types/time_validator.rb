# frozen_string_literal: true

require_relative "base_type_validator"

module Lutaml
  module Xsd
    module Validation
      module BaseTypes
        # Validates XSD time type
        #
        # The time type represents a time of day in the format: HH:MM:SS
        # with optional fractional seconds and timezone.
        #
        # @example Validating time values
        #   validator = TimeValidator.new
        #   validator.valid?("14:30:00")         # => true
        #   validator.valid?("14:30:00Z")        # => true
        #   validator.valid?("14:30:00.123")     # => true
        #   validator.valid?("14:30:00+05:30")   # => true
        #   validator.valid?("2:30:00")          # => false (must be padded)
        #   validator.valid?("25:00:00")         # => false (invalid hour)
        #
        class TimeValidator < BaseTypeValidator
          # ISO 8601 time pattern
          TIME_PATTERN = /^
            \d{2}:\d{2}:\d{2}       # Time part: HH:MM:SS
            (\.\d+)?                 # Optional fractional seconds
            (Z|[+-]\d{2}:\d{2})?    # Optional timezone
          $/x

          # Validate value is a valid time
          #
          # @param value [Object] The value to validate
          # @return [Boolean] true if value is a valid ISO 8601 time
          def valid?(value)
            return false if value.nil?

            str = to_string(value).strip
            return false unless str.match?(TIME_PATTERN)

            # Extract time part (before timezone and fractional seconds)
            time_part = str.split(/[Z+.-]/)[0]
            parts = time_part.split(":")

            # Validate ranges
            hour = parts[0].to_i
            minute = parts[1].to_i
            second = parts[2].to_i

            hour.between?(0, 23) &&
              minute >= 0 && minute <= 59 &&
              second >= 0 && second <= 59
          rescue StandardError
            false
          end

          # Generate error message for invalid time
          #
          # @param value [Object] The invalid value
          # @return [String] Error message
          def error_message(value)
            "Value '#{value}' is not a valid time. " \
              "Expected format: HH:MM:SS[.sss][Z|(+|-)HH:MM]"
          end
        end
      end
    end
  end
end
