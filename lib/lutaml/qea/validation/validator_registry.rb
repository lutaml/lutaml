# frozen_string_literal: true

module Lutaml
  module Qea
    module Validation
      # Registry for managing validators using the registry pattern
      # Allows dynamic registration and retrieval of validators
      #
      # @example Registering and using validators
      #   registry = ValidatorRegistry.new
      #   registry.register(:package, PackageValidator)
      #   registry.register(:class, ClassValidator)
      #
      #   validator = registry.get(:package)
      #   result = validator.new(context).validate
      class ValidatorRegistry
        def initialize
          @validators = {}
        end

        # Registers a validator class
        #
        # @param name [Symbol] Validator name/key
        # @param validator_class [Class] Validator class (must inherit from
        #   BaseValidator)
        # @raise [ArgumentError] if validator_class is not a BaseValidator
        # @return [void]
        def register(name, validator_class)
          unless validator_class.is_a?(Class)
            raise ArgumentError,
                  "Expected a Class, got #{validator_class.class}"
          end

          @validators[name] = validator_class
        end

        # Retrieves a validator class by name
        #
        # @param name [Symbol] Validator name/key
        # @return [Class, nil] Validator class or nil if not found
        def get(name)
          @validators[name]
        end

        # Retrieves a validator class by name, raising an error if not found
        #
        # @param name [Symbol] Validator name/key
        # @return [Class]
        # @raise [KeyError] if validator not found
        def fetch(name)
          @validators.fetch(name) do
            raise KeyError, "Validator '#{name}' not registered"
          end
        end

        # Checks if a validator is registered
        #
        # @param name [Symbol] Validator name/key
        # @return [Boolean]
        def registered?(name)
          @validators.key?(name)
        end

        # Returns all registered validator names
        #
        # @return [Array<Symbol>]
        def names
          @validators.keys
        end

        # Returns all registered validators
        #
        # @return [Hash<Symbol, Class>]
        def all
          @validators.dup
        end

        # Unregisters a validator
        #
        # @param name [Symbol] Validator name/key
        # @return [Class, nil] The unregistered validator class
        def unregister(name)
          @validators.delete(name)
        end

        # Clears all registered validators
        #
        # @return [void]
        def clear
          @validators.clear
        end

        # Creates a validator instance
        #
        # @param name [Symbol] Validator name/key
        # @param context [Hash] Validation context (must include :result key)
        # @return [BaseValidator] Validator instance
        # @raise [KeyError] if validator not found
        def create(name, context = {})
          result = context[:result] || ValidationResult.new
          fetch(name).new(result: result, context: context)
        end

        # Runs a validator and returns the result
        #
        # @param name [Symbol] Validator name/key
        # @param context [Hash] Validation context (must include :result key)
        # @return [ValidationResult]
        # @raise [KeyError] if validator not found
        def validate(name, context = {})
          validator = create(name, context)
          validator.call
          validator.result
        end

        # Runs multiple validators and merges their results
        #
        # @param names [Array<Symbol>] Validator names/keys
        # @param context [Hash] Validation context
        # @return [ValidationResult] Merged validation result
        def validate_all(names, context = {})
          result = context[:result] || ValidationResult.new
          context[:result] = result

          names.each do |name|
            validate(name, context)
          end

          result
        end
      end
    end
  end
end
