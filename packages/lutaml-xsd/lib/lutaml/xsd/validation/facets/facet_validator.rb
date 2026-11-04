# frozen_string_literal: true

module Lutaml
  module Xsd
    module Validation
      module Facets
        # Base class for all facet validators
        #
        # Facet validators validate values against specific XSD facet
        # constraints such as pattern, length, min/max values, etc.
        #
        # @abstract Subclasses must implement {#valid?} and {#error_message}
        #
        # @example Creating a custom facet validator
        #   class CustomFacetValidator < FacetValidator
        #     def valid?(value)
        #       # Custom validation logic
        #       value.start_with?('custom')
        #     end
        #
        #     def error_message(value)
        #       "Value '#{value}' does not match custom constraint"
        #     end
        #   end
        #
        class FacetValidator
          attr_reader :facet

          # Initialize the facet validator
          #
          # @param facet [Object] The facet object containing the constraint
          #   definition
          def initialize(facet)
            @facet = facet
          end

          # Validate a value against the facet constraint
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

          # Get the facet value
          #
          # @return [Object] The facet constraint value
          def facet_value
            facet.value
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

          # Safely convert value to integer
          #
          # @param value [Object] The value to convert
          # @return [Integer, nil] Integer value or nil if conversion fails
          def to_integer(value)
            Integer(value)
          rescue ArgumentError, TypeError
            nil
          end

          # Safely convert value to numeric
          #
          # @param value [Object] The value to convert
          # @return [Numeric, nil] Numeric value or nil if conversion fails
          def to_numeric(value)
            return value if value.is_a?(Numeric)

            Float(value)
          rescue ArgumentError, TypeError
            nil
          end
        end
      end
    end
  end
end
