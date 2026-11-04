# frozen_string_literal: true

require_relative "facet_validator"
require_relative "pattern_facet_validator"
require_relative "length_facet_validator"
require_relative "min_length_facet_validator"
require_relative "max_length_facet_validator"
require_relative "enumeration_facet_validator"
require_relative "min_inclusive_facet_validator"
require_relative "max_inclusive_facet_validator"
require_relative "min_exclusive_facet_validator"
require_relative "max_exclusive_facet_validator"
require_relative "total_digits_facet_validator"
require_relative "fraction_digits_facet_validator"
require_relative "white_space_facet_validator"

module Lutaml
  module Xsd
    module Validation
      module Facets
        # Registry for mapping facet types to their validators
        #
        # This registry provides a centralized lookup mechanism for
        # obtaining the appropriate validator for a given facet type.
        #
        # @example Getting a validator for a facet
        #   facet = Lutaml::Xsd::Pattern.new(value: "[A-Z]+")
        #   validator = FacetValidatorRegistry.validator_for(facet)
        #   validator.valid?("ABC")  # => true
        #
        class FacetValidatorRegistry
          # Map of facet classes to validator classes
          VALIDATORS = {
            "Lutaml::Xsd::Pattern" => PatternFacetValidator,
            "Lutaml::Xsd::Length" => LengthFacetValidator,
            "Lutaml::Xsd::MinLength" => MinLengthFacetValidator,
            "Lutaml::Xsd::MaxLength" => MaxLengthFacetValidator,
            "Lutaml::Xsd::Enumeration" => EnumerationFacetValidator,
            "Lutaml::Xsd::MinInclusive" => MinInclusiveFacetValidator,
            "Lutaml::Xsd::MaxInclusive" => MaxInclusiveFacetValidator,
            "Lutaml::Xsd::MinExclusive" => MinExclusiveFacetValidator,
            "Lutaml::Xsd::MaxExclusive" => MaxExclusiveFacetValidator,
            "Lutaml::Xsd::TotalDigits" => TotalDigitsFacetValidator,
            "Lutaml::Xsd::FractionDigits" => FractionDigitsFacetValidator,
            "Lutaml::Xsd::WhiteSpace" => WhiteSpaceFacetValidator,
          }.freeze

          class << self
            # Get validator instance for a facet
            #
            # @param facet [Object] The facet object
            # @return [FacetValidator] Validator instance for the facet
            # @raise [UnknownFacetError] if facet type is not registered
            def validator_for(facet)
              validator_class = VALIDATORS[facet.class.name]
              raise UnknownFacetError, facet.class.name unless validator_class

              validator_class.new(facet)
            end

            # Check if a facet type is registered
            #
            # @param facet [Object] The facet object or class
            # @return [Boolean] true if facet type is registered
            def registered?(facet)
              facet_class = facet.is_a?(Class) ? facet.name : facet.class.name
              VALIDATORS.key?(facet_class)
            end

            # Register a custom facet validator
            #
            # @param facet_class [Class, String] The facet class or class name
            # @param validator_class [Class] The validator class
            # @return [void]
            def register(facet_class, validator_class)
              facet_name = facet_class.is_a?(String) ? facet_class : facet_class.name
              VALIDATORS[facet_name] = validator_class
            end

            # Get all registered facet types
            #
            # @return [Array<String>] Array of registered facet class names
            def registered_facets
              VALIDATORS.keys
            end
          end

          # Error raised when an unknown facet type is encountered
          class UnknownFacetError < StandardError
            def initialize(facet_class_name)
              super("Unknown facet type: #{facet_class_name}. " \
                    "Registered facets: #{FacetValidatorRegistry.registered_facets.join(', ')}")
            end
          end
        end
      end
    end
  end
end
