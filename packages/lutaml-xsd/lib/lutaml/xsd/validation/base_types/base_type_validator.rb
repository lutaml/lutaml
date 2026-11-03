# frozen_string_literal: true

require "date"
require "time"
require "uri"

module Lutaml
  module Xsd
    module Validation
      module BaseTypes
        # Base class for all XSD built-in type validators
        #
        # Base type validators validate values against XSD built-in types
        # like string, integer, boolean, dateTime, etc.
        #
        # @abstract Subclasses must implement {#valid?} and {#error_message}
        #
        # @example Creating a custom type validator
        #   class CustomTypeValidator < BaseTypeValidator
        #     def valid?(value)
        #       # Custom validation logic
        #       value.start_with?('custom')
        #     end
        #
        #     def error_message(value)
        #       "Value '#{value}' is not a valid custom type"
        #     end
        #   end
        #
        class BaseTypeValidator
          # Validate a value against the type
          #
          # @abstract Subclasses must implement this method
          # @param value [String] The value to validate
          # @return [Boolean] true if value is valid, false otherwise
          # @raise [NotImplementedError] if not implemented by subclass
          def valid?(value)
            raise NotImplementedError,
                  "#{self.class.name} must implement #valid?"
          end

          # Generate an error message for an invalid value
          #
          # @abstract Subclasses must implement this method
          # @param value [String] The invalid value
          # @return [String] A descriptive error message
          # @raise [NotImplementedError] if not implemented by subclass
          def error_message(value)
            raise NotImplementedError,
                  "#{self.class.name} must implement #error_message"
          end

          # Get the type name
          #
          # @return [String] The XSD type name
          def type_name
            self.class.name.split("::").last.sub(/Validator$/, "")
          end

          class << self
            # Get validator for a specific XSD type name
            #
            # @param type_name [String] The XSD type name (e.g., 'string',
            #   'integer')
            # @return [BaseTypeValidator] Validator instance for the type
            def for(type_name)
              # Load registry on first access
              require_relative "base_type_validator_registry" unless defined?(BaseTypeValidatorRegistry)

              BaseTypeValidatorRegistry.validator_for(type_name)
            end

            # Check if a type is registered
            #
            # @param type_name [String] The XSD type name
            # @return [Boolean] true if type is registered
            def registered?(type_name)
              require_relative "base_type_validator_registry" unless defined?(BaseTypeValidatorRegistry)

              BaseTypeValidatorRegistry.registered?(type_name)
            end
          end

          protected

          # Safely convert value to string
          #
          # @param value [Object] The value to convert
          # @return [String] String representation of the value
          def to_string(value)
            return "" if value.nil?

            value.to_s
          end

          # Check if string is blank (nil or whitespace only)
          #
          # @param value [String] The value to check
          # @return [Boolean] true if blank
          def blank?(value)
            value.nil? || value.to_s.strip.empty?
          end
        end
      end
    end
  end
end
