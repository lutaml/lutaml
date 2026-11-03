# frozen_string_literal: true

require_relative "base_type_validator"

module Lutaml
  module Xsd
    module Validation
      module BaseTypes
        # Validates XSD boolean type
        #
        # The boolean type accepts the following values:
        # - true, false (literal boolean values)
        # - "true", "false" (string representations)
        # - "1", "0" (numeric representations)
        #
        # @example Validating boolean values
        #   validator = BooleanValidator.new
        #   validator.valid?("true")   # => true
        #   validator.valid?("false")  # => true
        #   validator.valid?("1")      # => true
        #   validator.valid?("0")      # => true
        #   validator.valid?(true)     # => true
        #   validator.valid?(false)    # => true
        #   validator.valid?("yes")    # => false
        #
        class BooleanValidator < BaseTypeValidator
          VALID_VALUES = %w[true false 1 0].freeze

          # Validate value is a valid boolean
          #
          # @param value [Object] The value to validate
          # @return [Boolean] true if value is a valid boolean representation
          def valid?(value)
            return false if value.nil?
            return true if value.is_a?(TrueClass) || value.is_a?(FalseClass)

            VALID_VALUES.include?(to_string(value).downcase)
          end

          # Generate error message for invalid boolean
          #
          # @param value [Object] The invalid value
          # @return [String] Error message
          def error_message(value)
            "Value '#{value}' is not a valid boolean. " \
              "Expected: true, false, 1, or 0"
          end
        end
      end
    end
  end
end
