# frozen_string_literal: true

require_relative "validation_rule"
require_relative "rules/element_structure_rule"
require_relative "rules/type_validation_rule"
require_relative "rules/attribute_validation_rule"
require_relative "rules/occurrence_validation_rule"
require_relative "rules/content_model_validation_rule"
require_relative "rules/identity_constraints_rule"
require_relative "rules/id_uniqueness_rule"

module Lutaml
  module Xsd
    module Validation
      # RuleRegistry manages validation rules
      #
      # This class implements the Registry pattern to manage validation rules.
      # It organizes rules by category and provides methods to register,
      # retrieve, and filter rules based on configuration.
      #
      # {RuleRegistry.default} builds the production rule set that the
      # Validator and the conformance harness share.
      #
      # @example Create and populate a registry
      #   registry = RuleRegistry.new(config)
      #   registry.register(ElementStructureRule.new)
      #   registry.register(TypeValidationRule.new)
      #
      # @example Get rules by category
      #   structure_rules = registry.rules_for_category(:structure)
      class RuleRegistry
        # @return [ValidationConfiguration] The validation configuration
        attr_reader :config

        # Initialize a new RuleRegistry
        #
        # @param config [ValidationConfiguration] The validation configuration
        def initialize(config)
          @config = config
          @rules = []
          @rules_by_category = Hash.new { |h, k| h[k] = [] }
        end

        # Production rule set, gated by the validation feature flags.
        #
        # @param config [ValidationConfiguration]
        # @return [RuleRegistry]
        def self.default(config)
          registry = new(config)
          registry.register(Rules::ElementStructureRule.new)
          if config.feature_enabled?(:validate_types)
            registry.register(Rules::TypeValidationRule.new)
          end
          if config.feature_enabled?(:validate_attributes)
            registry.register(Rules::AttributeValidationRule.new)
          end
          if config.feature_enabled?(:validate_occurrences)
            registry.register(Rules::OccurrenceValidationRule.new)
          end
          if config.feature_enabled?(:validate_content_models)
            registry.register(Rules::ContentModelValidationRule.new)
          end
          if config.feature_enabled?(:validate_identity_constraints)
            registry.register(Rules::IdentityConstraintsRule.new)
            registry.register(Rules::IdUniquenessRule.new)
          end
          registry
        end

        # Register a validation rule
        #
        # @param rule [ValidationRule] The rule to register
        # @return [void]
        #
        # @raise [ArgumentError] if rule is not a ValidationRule
        def register(rule)
          validate_rule!(rule)

          @rules << rule
          @rules_by_category[rule.category] << rule

          # Sort by priority after adding
          @rules_by_category[rule.category].sort_by!(&:priority)
        end

        # Register multiple rules at once
        #
        # @param rules [Array<ValidationRule>] Rules to register
        # @return [void]
        def register_all(rules)
          rules.each { |rule| register(rule) }
        end

        # Get all registered rules
        #
        # @param enabled_only [Boolean] Return only enabled rules
        # @return [Array<ValidationRule>]
        def all_rules(enabled_only: true)
          rules = @rules
          rules = rules.select(&:enabled?) if enabled_only
          rules
        end

        # Get rules for a specific category
        #
        # @param category [Symbol] The rule category
        # @param enabled_only [Boolean] Return only enabled rules
        # @return [Array<ValidationRule>]
        def rules_for_category(category, enabled_only: true)
          rules = @rules_by_category[category]
          rules = rules.select(&:enabled?) if enabled_only
          rules
        end

        # Get structure validation rules
        #
        # @return [Array<ValidationRule>]
        def structure_rules
          rules_for_category(:structure)
        end

        # Get type validation rules
        #
        # @return [Array<ValidationRule>]
        def type_rules
          rules_for_category(:type)
        end

        # Get constraint validation rules
        #
        # @return [Array<ValidationRule>]
        def constraint_rules
          rules_for_category(:constraint)
        end

        # Get facet validation rules
        #
        # @return [Array<ValidationRule>]
        def facet_rules
          rules_for_category(:facet)
        end

        # Get identity constraint validation rules
        #
        # @return [Array<ValidationRule>]
        def identity_rules
          rules_for_category(:identity)
        end

        # Get all categories with registered rules
        #
        # @return [Array<Symbol>]
        def categories
          @rules_by_category.keys
        end

        # Check if a category has any rules
        #
        # @param category [Symbol] The category
        # @return [Boolean]
        def has_rules_for?(category)
          rules_for_category(category).any?
        end

        # Get count of rules per category
        #
        # @return [Hash<Symbol, Integer>]
        def rule_counts
          categories.each_with_object({}) do |category, counts|
            counts[category] = rules_for_category(category).size
          end
        end

        # Clear all registered rules
        #
        # @return [void]
        def clear
          @rules.clear
          @rules_by_category.clear
        end

        # Remove a specific rule
        #
        # @param rule [ValidationRule] The rule to remove
        # @return [Boolean] true if removed, false if not found
        def unregister(rule)
          removed = @rules.delete(rule)
          @rules_by_category[rule.category].delete(rule) if removed
          !removed.nil?
        end

        # Enable all rules in a category
        #
        # @param category [Symbol] The category
        # @return [void]
        def enable_category(category)
          @rules_by_category[category].each(&:enable!)
        end

        # Disable all rules in a category
        #
        # @param category [Symbol] The category
        # @return [void]
        def disable_category(category)
          @rules_by_category[category].each(&:disable!)
        end

        # Get applicable rules based on configuration
        #
        # @return [Array<ValidationRule>]
        def applicable_rules
          all_rules.select { |rule| rule.applicable?(@config) }
        end

        # Convert to hash representation
        #
        # @return [Hash]
        def to_h
          {
            total_rules: @rules.size,
            enabled_rules: all_rules.size,
            categories: categories,
            rule_counts: rule_counts,
            rules: @rules.map(&:to_h),
          }
        end

        # String representation
        #
        # @return [String]
        def to_s
          "RuleRegistry(#{@rules.size} rules, #{categories.size} categories)"
        end

        # Detailed string representation
        #
        # @return [String]
        def inspect
          "#<#{self.class.name} " \
            "total=#{@rules.size} " \
            "enabled=#{all_rules.size} " \
            "categories=#{categories.inspect}>"
        end

        private

        # Validate that the rule is a ValidationRule
        #
        # @param rule [Object] The object to validate
        # @raise [ArgumentError] if not a ValidationRule
        def validate_rule!(rule)
          return if rule.is_a?(ValidationRule)

          raise ArgumentError,
                "Expected ValidationRule, got #{rule.class}"
        end
      end
    end
  end
end
