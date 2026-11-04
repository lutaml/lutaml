# frozen_string_literal: true

require_relative "base_type_validator"
require_relative "string_validator"
require_relative "boolean_validator"
require_relative "integer_validator"
require_relative "decimal_validator"
require_relative "date_time_validator"
require_relative "date_validator"
require_relative "time_validator"
require_relative "any_uri_validator"
require_relative "qname_validator"

module Lutaml
  module Xsd
    module Validation
      module BaseTypes
        # Registry for mapping XSD built-in types to their validators
        #
        # This registry provides a centralized lookup mechanism for
        # obtaining the appropriate validator for a given XSD type name.
        #
        # @example Getting a validator for a type
        #   validator = BaseTypeValidatorRegistry.validator_for("string")
        #   validator.valid?("hello")  # => true
        #
        class BaseTypeValidatorRegistry
          # Singleton instances of validators for reuse
          @validators = {}

          # Map of type names to validator classes
          VALIDATOR_CLASSES = {
            # String types
            "string" => StringValidator,
            "normalizedString" => StringValidator,
            "token" => StringValidator,

            # Boolean type
            "boolean" => BooleanValidator,

            # Numeric types
            "decimal" => DecimalValidator,
            "integer" => IntegerValidator,
            "positiveInteger" => IntegerValidator,
            "negativeInteger" => IntegerValidator,
            "nonPositiveInteger" => IntegerValidator,
            "nonNegativeInteger" => IntegerValidator,
            "long" => IntegerValidator,
            "int" => IntegerValidator,
            "short" => IntegerValidator,
            "byte" => IntegerValidator,
            "unsignedLong" => IntegerValidator,
            "unsignedInt" => IntegerValidator,
            "unsignedShort" => IntegerValidator,
            "unsignedByte" => IntegerValidator,
            "float" => DecimalValidator,
            "double" => DecimalValidator,

            # Date/Time types
            "dateTime" => DateTimeValidator,
            "date" => DateValidator,
            "time" => TimeValidator,

            # URI type
            "anyURI" => AnyURIValidator,

            # QName type
            "QName" => QNameValidator,
          }.freeze

          class << self
            # Get validator instance for a type name
            #
            # @param type_name [String] The XSD type name
            # @return [BaseTypeValidator] Validator instance for the type
            # @raise [UnknownTypeError] if type is not registered
            def validator_for(type_name)
              # Return cached validator if exists
              return @validators[type_name] if @validators.key?(type_name)

              # Look up validator class
              validator_class = VALIDATOR_CLASSES[type_name]
              unless validator_class
                raise UnknownTypeError,
                      "Unknown XSD type: #{type_name}"
              end

              # Create and cache validator instance
              @validators[type_name] = validator_class.new
            end

            # Check if a type is registered
            #
            # @param type_name [String] The XSD type name
            # @return [Boolean] true if type is registered
            def registered?(type_name)
              VALIDATOR_CLASSES.key?(type_name)
            end

            # Register a custom type validator
            #
            # @param type_name [String] The XSD type name
            # @param validator_class [Class] The validator class
            # @return [void]
            def register(type_name, validator_class)
              VALIDATOR_CLASSES[type_name] = validator_class
              @validators.delete(type_name) # Clear cached instance
            end

            # Get all registered type names
            #
            # @return [Array<String>] Array of registered type names
            def registered_types
              VALIDATOR_CLASSES.keys
            end

            # Clear validator cache
            #
            # @return [void]
            def clear_cache
              @validators.clear
            end
          end

          # Error raised when an unknown type is encountered
          class UnknownTypeError < StandardError
            def initialize(message)
              super("#{message}. " \
                    "Registered types: #{BaseTypeValidatorRegistry.registered_types.join(', ')}")
            end
          end
        end
      end
    end
  end
end
