# frozen_string_literal: true

require_relative "base_type_validator"

module Lutaml
  module Xsd
    module Validation
      module BaseTypes
        # Validates XSD string type
        #
        # The string type represents character strings in XML. All values
        # are valid strings unless additional facets restrict them.
        #
        # @example Validating string values
        #   validator = StringValidator.new
        #   validator.valid?("hello")      # => true
        #   validator.valid?("123")        # => true
        #   validator.valid?("")           # => true
        #   validator.valid?(nil)          # => false
        #
        class StringValidator < BaseTypeValidator
          # Validate value is a valid string
          #
          # @param value [Object] The value to validate
          # @return [Boolean] true if value can be represented as string
          def valid?(value)
            !value.nil?
          end

          # Generate error message for invalid string
          #
          # @param value [Object] The invalid value
          # @return [String] Error message
          def error_message(value)
            "Value '#{value}' is not a valid string (cannot be nil)"
          end
        end
      end
    end
  end
end
