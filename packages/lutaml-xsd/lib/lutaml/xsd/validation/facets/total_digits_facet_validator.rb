# frozen_string_literal: true

require_relative "facet_validator"

module Lutaml
  module Xsd
    module Validation
      module Facets
        # Validates values against XSD totalDigits facet
        #
        # The totalDigits facet specifies the maximum number of digits
        # (excluding leading zeros, trailing zeros after decimal point,
        # and decimal point itself) for decimal and integer types.
        #
        # @example Validating total digits
        #   facet = Lutaml::Xsd::TotalDigits.new(value: "5")
        #   validator = TotalDigitsFacetValidator.new(facet)
        #   validator.valid?("12345")    # => true (5 digits)
        #   validator.valid?("123.45")   # => true (5 digits)
        #   validator.valid?("123456")   # => false (6 digits)
        #   validator.error_message("123456")
        #   # => "Value has 6 digits, exceeds maximum of 5 total digits"
        #
        class TotalDigitsFacetValidator < FacetValidator
          # Validate value has correct total digits
          #
          # @param value [String, Numeric] The value to validate
          # @return [Boolean] true if total digits <= maximum, false
          #   otherwise
          def valid?(value)
            return false if value.nil?

            max_digits = to_integer(facet_value)
            return false unless max_digits

            count_digits(value) <= max_digits
          end

          # Generate error message for total digits violation
          #
          # @param value [String, Numeric] The invalid value
          # @return [String] Error message describing the violation
          def error_message(value)
            actual_digits = count_digits(value)
            "Value has #{actual_digits} digits, exceeds maximum of " \
              "#{facet_value} total digits"
          end

          private

          # Count total significant digits in value
          #
          # @param value [String, Numeric] The value to count
          # @return [Integer] Number of significant digits
          def count_digits(value)
            # Convert to string and remove sign, decimal point, and
            # leading/trailing zeros
            str = to_string(value).gsub(/[+-]/, "").gsub(".", "")
            # Remove leading zeros
            str = str.sub(/^0+/, "")
            # For decimals, remove trailing zeros after decimal point
            str.length
          end
        end
      end
    end
  end
end
