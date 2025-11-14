# frozen_string_literal: true

require_relative "class_transformer"
require_relative "attribute_transformer"
require_relative "operation_transformer"
require_relative "association_transformer"
require_relative "generalization_transformer"
require_relative "package_transformer"
require_relative "diagram_transformer"

module Lutaml
  module Qea
    module Factory
      # Registry for EA to UML transformers
      # Implements the Registry pattern for transformer lookup
      class TransformerRegistry
        class << self
          # Get or initialize the registry
          # @return [Hash] Registry hash
          def registry
            @registry ||= {}
          end

          # Register a transformer for an EA type
          # @param ea_type [Symbol, String] EA model type
          # @param transformer_class [Class] Transformer class
          def register(ea_type, transformer_class)
            registry[ea_type.to_sym] = transformer_class
          end

          # Get transformer for an EA type
          # @param ea_type [Symbol, String] EA model type
          # @return [Class, nil] Transformer class or nil if not found
          def transformer_for(ea_type)
            registry[ea_type.to_sym]
          end

          # Get all registered transformers
          # @return [Hash] All registered transformers
          def all_transformers
            registry.dup
          end

          # Check if a transformer is registered for a type
          # @param ea_type [Symbol, String] EA model type
          # @return [Boolean] True if registered
          def registered?(ea_type)
            registry.key?(ea_type.to_sym)
          end

          # Clear all registrations (mainly for testing)
          def clear
            @registry = {}
          end

          # Reset to default registrations
          def reset_defaults
            clear
            register_defaults
          end

          # Register default transformers
          def register_defaults
            # Object types
            register(:class, ClassTransformer)
            register(:interface, ClassTransformer)
            register(:package, PackageTransformer)

            # Connector types
            register(:association, AssociationTransformer)
            register(:generalization, GeneralizationTransformer)

            # Other types
            register(:attribute, AttributeTransformer)
            register(:operation, OperationTransformer)
            register(:diagram, DiagramTransformer)
          end
        end

        # Initialize registry with default transformers
        register_defaults
      end
    end
  end
end
