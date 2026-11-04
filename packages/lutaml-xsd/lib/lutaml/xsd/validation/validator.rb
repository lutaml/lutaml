# frozen_string_literal: true

require_relative "engine_context"
require_relative "validation_configuration"
require_relative "validation_job"
require_relative "validation_result"

module Lutaml
  module Xsd
    module Validation
      # Validator provides the main facade for XML validation against XSD schemas
      #
      # This class serves as the primary entry point for validating XML instances
      # against XSD schemas loaded from packages or repositories. It handles
      # schema resolution, configuration loading, and delegates the actual
      # validation work to ValidationJob.
      #
      # @example Validate XML with a schema package
      #   validator = Lutaml::Xsd::Validator.new("schemas.lxr")
      #   result = validator.validate("<root>...</root>")
      #   puts result.valid? ? "Valid!" : "Invalid: #{result.errors}"
      #
      # @example Validate with custom configuration
      #   config = Lutaml::Xsd::Validation::ValidationConfiguration.from_file("config.yml")
      #   validator = Lutaml::Xsd::Validator.new("schemas.lxr", config: config)
      #   result = validator.validate(xml_content)
      #
      # @example Validate with schema repository
      #   repo = Lutaml::Xsd::SchemaRepository.from_package("schemas.lxr")
      #   validator = Lutaml::Xsd::Validator.new(repo)
      #   result = validator.validate(xml_content)
      class Validator
        # Initialize a new Validator
        #
        # @param schema_source [String, SchemaRepository] Path to schema package
        #   (.lxr file) or a SchemaRepository instance
        # @param config [Hash, String, ValidationConfiguration, nil] Configuration
        #   options as a Hash, path to YAML config file, ValidationConfiguration
        #   instance, or nil for defaults
        #
        # @raise [ArgumentError] if schema_source is invalid type
        # @raise [SchemaNotFoundError] if schema package cannot be found
        # @raise [ConfigurationError] if configuration is invalid
        def initialize(schema_source, config: nil)
          @repository = resolve_repository(schema_source)
          @config = load_configuration(config)
          @rule_registry = build_rule_registry
        end

        # Validate an XML document against the loaded schema
        #
        # @param xml_content [String] The XML content to validate
        #
        # @return [ValidationResult] The validation result containing errors
        #   and validation status
        #
        # @raise [ArgumentError] if xml_content is nil or empty
        def validate(xml_content)
          raise ArgumentError, "xml_content cannot be nil" if xml_content.nil?

          if xml_content.empty?
            raise ArgumentError,
                  "xml_content cannot be empty"
          end

          job = Validation::ValidationJob.new(
            xml_content: xml_content,
            repository: @repository,
            rule_registry: @rule_registry,
            config: @config,
          )

          job.execute
        end

        private

        # Resolve schema source to SchemaRepository
        #
        # @param source [String, SchemaRepository] The schema source
        # @return [SchemaRepository] The resolved repository
        # @raise [ArgumentError] if source type is unsupported
        def resolve_repository(source)
          case source
          when String
            SchemaRepository.from_package(source)
          when SchemaRepository
            source
          else
            raise ArgumentError,
                  "Invalid schema source type: #{source.class}. " \
                  "Expected String (package path) or SchemaRepository"
          end
        end

        # Load and initialize configuration
        #
        # @param config [Hash, String, ValidationConfiguration, nil] Config input
        # @return [ValidationConfiguration] The loaded configuration
        # @raise [ConfigurationError] if configuration is invalid
        def load_configuration(config)
          case config
          when nil
            Validation::ValidationConfiguration.default
          when String
            Validation::ValidationConfiguration.from_file(config)
          when Hash
            Validation::ValidationConfiguration.new(config)
          when Validation::ValidationConfiguration
            config
          else
            raise ConfigurationError,
                  "Invalid configuration type: #{config.class}"
          end
        end

        # Build rule registry from configuration
        #
        # @return [RuleRegistry] The initialized rule registry
        def build_rule_registry
          require_relative "rule_registry"
          Validation::RuleRegistry.default(@config)
        end
      end
    end
  end
end
