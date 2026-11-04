# frozen_string_literal: true

require_relative "base_type_validator"

module Lutaml
  module Xsd
    module Validation
      module BaseTypes
        # Validates XSD decimal type
        #
        # The decimal type represents arbitrary-precision decimal numbers.
        # Valid values include integers and decimals with optional sign.
        #
        # @example Validating decimal values
        #   validator = DecimalValidator.new
        #   validator.valid?("123.45")    # => true
        #   validator.valid?("-0.5")      # => true
        #   validator.valid?("+3.14")     # => true
        #   validator.valid?("100")       # => true
        #   validator.valid?(".5")        # => true
        #   validator.valid?("5.")        # => true
        #   validator.valid?("abc")       # => false
        #
        class DecimalValidator < BaseTypeValidator
          # Pattern for valid decimal format
          # Using possessive quantifiers to prevent polynomial backtracking
          DECIMAL_PATTERN = /^[+-]?(?>\d++\.?\d*|\.\d+)$/

          # Validate value is a valid decimal
          #
          # @param value [Object] The value to validate
          # @return [Boolean] true if value is a valid decimal
          def valid?(value)
            return false if value.nil?
            return true if value.is_a?(Numeric)

            str = to_string(value).strip
            return false if str.empty?

            # Check pattern first for performance
            return false unless str.match?(DECIMAL_PATTERN)

            # Verify it can be parsed as Float
            Float(str)
            true
          rescue ArgumentError, TypeError
            false
          end

          # Generate error message for invalid decimal
          #
          # @param value [Object] The invalid value
          # @return [String] Error message
          def error_message(value)
            "Value '#{value}' is not a valid decimal number"
          end
        end
      end
    end
  end
end
