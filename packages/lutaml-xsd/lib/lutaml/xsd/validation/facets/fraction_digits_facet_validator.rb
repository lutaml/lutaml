# frozen_string_literal: true

require_relative "facet_validator"

module Lutaml
  module Xsd
    module Validation
      module Facets
        # Validates values against XSD fractionDigits facet
        #
        # The fractionDigits facet specifies the maximum number of digits
        # in the fractional part (after decimal point) for decimal types.
        #
        # @example Validating fraction digits
        #   facet = Lutaml::Xsd::FractionDigits.new(value: "2")
        #   validator = FractionDigitsFacetValidator.new(facet)
        #   validator.valid?("123.45")   # => true (2 fraction digits)
        #   validator.valid?("123.4")    # => true (1 fraction digit)
        #   validator.valid?("123.456")  # => false (3 fraction digits)
        #   validator.error_message("123.456")
        #   # => "Value has 3 fraction digits, exceeds maximum of 2"
        #
        class FractionDigitsFacetValidator < FacetValidator
          # Validate value has correct fraction digits
          #
          # @param value [String, Numeric] The value to validate
          # @return [Boolean] true if fraction digits <= maximum, false
          #   otherwise
          def valid?(value)
            return false if value.nil?

            max_fraction = to_integer(facet_value)
            return false unless max_fraction

            count_fraction_digits(value) <= max_fraction
          end

          # Generate error message for fraction digits violation
          #
          # @param value [String, Numeric] The invalid value
          # @return [String] Error message describing the violation
          def error_message(value)
            actual_fraction = count_fraction_digits(value)
            "Value has #{actual_fraction} fraction digits, exceeds " \
              "maximum of #{facet_value}"
          end

          private

          # Count digits in fractional part
          #
          # @param value [String, Numeric] The value to count
          # @return [Integer] Number of fraction digits
          def count_fraction_digits(value)
            str = to_string(value)
            # Find decimal point
            decimal_index = str.index(".")
            return 0 unless decimal_index

            # Count digits after decimal point (excluding trailing zeros)
            fraction_part = str[(decimal_index + 1)..]
            # Remove trailing zeros without regex to avoid polynomial backtracking
            fraction_part = fraction_part.reverse.sub(/\A0+/, "").reverse
            fraction_part.length
          end
        end
      end
    end
  end
end
