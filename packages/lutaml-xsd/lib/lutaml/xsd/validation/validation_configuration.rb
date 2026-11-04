# frozen_string_literal: true

require "yaml"

module Lutaml
  module Xsd
    module Validation
      # ValidationConfiguration manages validation behavior settings
      #
      # This class loads and manages all configuration settings for XML
      # validation. It supports loading from YAML files, Hash objects,
      # or using sensible defaults.
      #
      # @example Load from YAML file
      #   config = ValidationConfiguration.from_file("config/validation.yml")
      #
      # @example Create from Hash
      #   config = ValidationConfiguration.new({
      #     strict_mode: true,
      #     stop_on_first_error: false
      #   })
      #
      # @example Use defaults
      #   config = ValidationConfiguration.default
      class ValidationConfiguration
        attr_reader :config_hash

        # Default configuration file path
        DEFAULT_CONFIG_PATH = File.join(
          __dir__, "..", "..", "..", "..", "config", "validation.yml"
        )

        # Initialize configuration from hash
        #
        # @param config_hash [Hash] Configuration settings
        def initialize(config_hash = {})
          @config_hash = config_hash
        end

        # Load configuration from YAML file
        #
        # @param path [String] Path to YAML configuration file
        # @return [ValidationConfiguration] New configuration instance
        # @raise [ConfigurationError] if file cannot be loaded
        def self.from_file(path)
          yaml_content = YAML.load_file(path)
          new(yaml_content)
        rescue Errno::ENOENT => e
          raise ConfigurationError,
                "Configuration file not found: #{path} (#{e.message})"
        rescue Psych::SyntaxError => e
          raise ConfigurationError,
                "Invalid YAML in configuration file: #{path} (#{e.message})"
        end

        # Load default configuration
        #
        # @return [ValidationConfiguration] Default configuration instance
        def self.default
          if File.exist?(DEFAULT_CONFIG_PATH)
            from_file(DEFAULT_CONFIG_PATH)
          else
            new(default_config_hash)
          end
        end

        # Check if strict mode is enabled
        #
        # @return [Boolean]
        def strict_mode?
          get_nested("validation", "strict_mode") || false
        end

        # Check if validation should stop on first error
        #
        # @return [Boolean]
        def stop_on_first_error?
          get_nested("validation", "stop_on_first_error") || false
        end

        # Get maximum number of errors to collect
        #
        # @return [Integer]
        def max_errors
          get_nested("validation", "max_errors") || 100
        end

        # Check if a validation feature is enabled
        #
        # @param feature [Symbol] Feature name (e.g., :validate_types)
        # @return [Boolean]
        def feature_enabled?(feature)
          get_nested("validation", "features", feature.to_s) != false
        end

        # Get error reporting verbosity level
        #
        # @return [Symbol] :minimal, :normal, :verbose, or :debug
        def verbosity
          level = get_nested("validation", "error_reporting", "verbosity")
          (level || "normal").to_sym
        end

        # Check if colorized output is enabled
        #
        # @return [Boolean]
        def colorize_output?
          get_nested("validation", "error_reporting", "colorize") != false
        end

        # Check if XPath should be included in errors
        #
        # @return [Boolean]
        def include_xpath?
          get_nested("validation", "error_reporting", "include_xpath") != false
        end

        # Check if line numbers should be included in errors
        #
        # @return [Boolean]
        def include_line_number?
          get_nested(
            "validation", "error_reporting", "include_line_number"
          ) != false
        end

        # Check if suggestions should be included in errors
        #
        # @return [Boolean]
        def include_suggestions?
          get_nested(
            "validation", "error_reporting", "include_suggestions"
          ) != false
        end

        # Check if network access is allowed for schema resolution
        #
        # @return [Boolean]
        def allow_network?
          get_nested(
            "validation", "schema_resolution", "allow_network"
          ) != false
        end

        # Check if schemas should be cached
        #
        # @return [Boolean]
        def cache_schemas?
          get_nested("validation", "schema_resolution",
                     "cache_schemas") != false
        end

        # Get schema cache directory
        #
        # @return [String]
        def cache_dir
          get_nested("validation", "schema_resolution", "cache_dir") ||
            "tmp/schema_cache"
        end

        # Get network timeout for schema fetching
        #
        # @return [Integer] Timeout in seconds
        def network_timeout
          get_nested("validation", "schema_resolution", "network_timeout") || 30
        end

        # Convert configuration to hash
        #
        # @return [Hash]
        def to_h
          deep_dup(@config_hash)
        end

        private

        # Deep duplicate a hash structure
        #
        # @param obj [Object] Object to duplicate
        # @return [Object] Duplicated object
        def deep_dup(obj)
          case obj
          when Hash
            obj.transform_values do |value|
              deep_dup(value)
            end
          when Array
            obj.map { |item| deep_dup(item) }
          when String
            obj.dup
          when Symbol, Numeric, TrueClass, FalseClass, NilClass
            # These objects are immutable or frozen, return as-is
            obj
          else
            # Try to duplicate, if it fails return the object as-is
            begin
              obj.dup
            rescue TypeError
              obj
            end
          end
        end

        # Get nested configuration value
        #
        # @param keys [Array<String>] Path to configuration value
        # @return [Object, nil] Configuration value or nil
        def get_nested(*keys)
          keys.reduce(@config_hash) do |hash, key|
            return nil unless hash.is_a?(Hash)

            # Check for key existence to handle false values properly
            if hash.key?(key)
              hash[key]
            elsif hash.key?(key.to_s)
              hash[key.to_s]
            elsif hash.key?(key.to_sym)
              hash[key.to_sym]
            end
          end
        end

        # Default configuration hash
        #
        # @return [Hash]
        def self.default_config_hash
          {
            "validation" => {
              "strict_mode" => true,
              "stop_on_first_error" => false,
              "max_errors" => 100,
              "features" => {
                "validate_types" => true,
                "validate_attributes" => true,
                "validate_occurrences" => true,
                "validate_identity_constraints" => true,
                "validate_facets" => true,
                "validate_content_models" => true,
                "validate_namespaces" => true,
                "engine_validation" => true,
              },
              "error_reporting" => {
                "include_xpath" => true,
                "include_line_number" => true,
                "include_suggestions" => true,
                "colorize" => true,
                "verbosity" => "normal",
              },
              "schema_resolution" => {
                "allow_network" => true,
                "cache_schemas" => true,
                "cache_dir" => "tmp/schema_cache",
                "network_timeout" => 30,
              },
            },
          }
        end
      end
    end
  end
end
