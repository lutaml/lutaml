# frozen_string_literal: true

require_relative "base_type_validator"

module Lutaml
  module Xsd
    module Validation
      module BaseTypes
        # Validates XSD integer type
        #
        # The integer type represents arbitrary-precision integers.
        # Valid values include positive, negative, and zero integers.
        #
        # @example Validating integer values
        #   validator = IntegerValidator.new
        #   validator.valid?("123")      # => true
        #   validator.valid?("-456")     # => true
        #   validator.valid?("0")        # => true
        #   validator.valid?("+789")     # => true
        #   validator.valid?("12.34")    # => false
        #   validator.valid?("abc")      # => false
        #
        class IntegerValidator < BaseTypeValidator
          # Pattern for valid integer format
          INTEGER_PATTERN = /^[+-]?\d+$/

          # Validate value is a valid integer
          #
          # @param value [Object] The value to validate
          # @return [Boolean] true if value is a valid integer
          def valid?(value)
            return false if value.nil?
            return true if value.is_a?(Integer)

            str = to_string(value).strip
            return false if str.empty?

            # Check pattern first for performance
            return false unless str.match?(INTEGER_PATTERN)

            # Verify it can be parsed as Integer
            Integer(str)
            true
          rescue ArgumentError, TypeError
            false
          end

          # Generate error message for invalid integer
          #
          # @param value [Object] The invalid value
          # @return [String] Error message
          def error_message(value)
            "Value '#{value}' is not a valid integer"
          end
        end
      end
    end
  end
end
