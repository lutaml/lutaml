# frozen_string_literal: true

require "yaml"

module Lutaml
  module UmlRepository
    # PackageMetadata provides external configuration of package metadata
    # without modifying the UML model itself.
    #
    # This class enables:
    # - XSD generation: Get xmlns, targetNamespace from package
    # - Documentation: Get package descriptions
    # - Styling: Get package-specific styling rules
    # - Validation: Get package constraints
    #
    # Configuration format (YAML):
    #   packages:
    #     "ModelRoot::i-UR::uro":
    #       xmlns: "http://www.kantei.go.jp/jp/singi/tiiki/..."
    #       targetNamespace: "http://www.kantei.go.jp/jp/..."
    #       schemaLocation: "../../schemas/uro/2.0/urbanObject.xsd"
    #       prefix: "uro"
    #       documentation: "Urban Object package"
    #
    #     "ModelRoot::CityGML2.0::*":  # Wildcard support
    #       xmlns: "http://www.opengis.net/citygml/2.0"
    #       prefix: "core"
    #
    # @example Basic usage
    #   metadata = PackageMetadata.new("config/package_metadata.yml")
    #   xmlns = metadata.xmlns_for("ModelRoot::i-UR::uro")
    #   # => "http://www.kantei.go.jp/jp/singi/tiiki/..."
    #
    # @example Wildcard matching
    #   metadata = PackageMetadata.new("config/package_metadata.yml")
    #   prefix = metadata.prefix_for("ModelRoot::CityGML2.0::Core")
    #   # => "core" (matches wildcard pattern)
    #
    class PackageMetadata
      # @return [Hash] The loaded configuration
      attr_reader :config

      # Initialize a new PackageMetadata instance
      #
      # @param config_path [String, nil] Path to YAML configuration file.
      #   If nil, creates an empty configuration.
      # @raise [Errno::ENOENT] if config file doesn't exist
      # @raise [Psych::SyntaxError] if YAML is invalid
      def initialize(config_path = nil)
        @config = load_config(config_path)
        @cache = {}
      end

      # Get complete metadata for a package path
      #
      # Matches exact paths first, then tries wildcard patterns.
      # Returns merged metadata from all matching patterns.
      #
      # @param package_path [String] Fully qualified package path
      #   (e.g., "ModelRoot::i-UR::uro")
      # @return [Hash] Merged metadata hash, or empty hash if no match
      #
      # @example
      #   metadata.metadata_for("ModelRoot::i-UR::uro")
      #   # => { xmlns: "...", prefix: "uro", ... }
      def metadata_for(package_path)
        return {} unless package_path
        return @cache[package_path] if @cache.key?(package_path)

        result = find_metadata(package_path)
        @cache[package_path] = result
        result
      end

      # Get xmlns (XML namespace) for a package
      #
      # @param package_path [String] Fully qualified package path
      # @return [String, nil] XML namespace URI, or nil if not found
      #
      # @example
      #   metadata.xmlns_for("ModelRoot::i-UR::uro")
      #   # => "http://www.kantei.go.jp/jp/singi/tiiki/..."
      def xmlns_for(package_path)
        metadata_for(package_path)[:xmlns]
      end

      # Get target namespace for a package
      #
      # @param package_path [String] Fully qualified package path
      # @return [String, nil] Target namespace URI, or nil if not found
      def target_namespace_for(package_path)
        metadata_for(package_path)[:targetNamespace]
      end

      # Get schema location for a package
      #
      # @param package_path [String] Fully qualified package path
      # @return [String, nil] Schema location path, or nil if not found
      def schema_location_for(package_path)
        metadata_for(package_path)[:schemaLocation]
      end

      # Get namespace prefix for a package
      #
      # @param package_path [String] Fully qualified package path
      # @return [String, nil] Namespace prefix, or nil if not found
      #
      # @example
      #   metadata.prefix_for("ModelRoot::i-UR::uro")
      #   # => "uro"
      def prefix_for(package_path)
        metadata_for(package_path)[:prefix]
      end

      # Get documentation for a package
      #
      # @param package_path [String] Fully qualified package path
      # @return [String, nil] Documentation text, or nil if not found
      def documentation_for(package_path)
        metadata_for(package_path)[:documentation]
      end

      # Check if metadata exists for a package path
      #
      # @param package_path [String] Fully qualified package path
      # @return [Boolean] true if any metadata exists, false otherwise
      def has_metadata?(package_path)
        !metadata_for(package_path).empty?
      end

      # Get all configured package paths (including wildcards)
      #
      # @return [Array<String>] List of all package path patterns
      def package_paths
        packages_config.keys
      end

      # Clear the metadata cache
      #
      # Useful after modifying configuration or for testing.
      #
      # @return [void]
      def clear_cache
        @cache.clear
      end

      private

      # Load configuration from YAML file
      #
      # @param config_path [String, nil] Path to YAML file
      # @return [Hash] Loaded configuration
      # @raise [Errno::ENOENT] if file doesn't exist
      # @raise [Psych::SyntaxError] if YAML is invalid
      def load_config(config_path)
        return { "packages" => {} } if config_path.nil?

        unless File.exist?(config_path)
          raise Errno::ENOENT, "Configuration file not found: #{config_path}"
        end

        content = File.read(config_path)
        parsed = YAML.safe_load(content, permitted_classes: [Symbol])

        # Normalize configuration structure
        unless parsed.is_a?(Hash) && parsed["packages"].is_a?(Hash)
          raise ArgumentError, "Invalid configuration format. Expected 'packages' key with hash value."
        end

        parsed
      rescue Psych::SyntaxError => e
        # Re-raise with additional context
        raise Psych::SyntaxError.new(
          config_path,
          e.line,
          e.column,
          e.offset,
          e.problem,
          "Invalid YAML syntax in #{config_path}: #{e.message}"
        )
      end

      # Get packages section from config
      #
      # @return [Hash] Packages configuration hash
      def packages_config
        @config["packages"] || {}
      end

      # Find metadata for a package path
      #
      # Tries exact match first, then wildcard patterns.
      # Exact matches take precedence over wildcard matches.
      #
      # @param package_path [String] Package path to search
      # @return [Hash] Merged metadata, or empty hash
      def find_metadata(package_path)
        result = {}

        # Try wildcard patterns first
        wildcard_matches = find_wildcard_matches(package_path)
        wildcard_matches.each do |match|
          result.merge!(symbolize_keys(packages_config[match]))
        end

        # Then apply exact match (takes precedence)
        if packages_config.key?(package_path)
          result.merge!(symbolize_keys(packages_config[package_path]))
        end

        result
      end

      # Find wildcard patterns that match a package path
      #
      # Supports patterns like:
      # - "Root::*" - matches any direct child of Root
      # - "Root::Sub::*" - matches any direct child of Root::Sub
      # - "Root::*::Sub" - matches any package with Root as grandparent and Sub as child
      #
      # @param package_path [String] Package path to match
      # @return [Array<String>] List of matching wildcard patterns
      def find_wildcard_matches(package_path)
        wildcard_patterns = packages_config.keys.select { |k| k.include?("*") }

        wildcard_patterns.select do |pattern|
          matches_wildcard_pattern?(package_path, pattern)
        end
      end

      # Check if a package path matches a wildcard pattern
      #
      # @param path [String] Package path to test
      # @param pattern [String] Wildcard pattern
      # @return [Boolean] true if path matches pattern
      def matches_wildcard_pattern?(path, pattern)
        # Convert wildcard pattern to regex
        # Escape special regex chars except *
        regex_pattern = Regexp.escape(pattern).gsub('\*', '[^:]+')
        regex = /^#{regex_pattern}$/

        !!(path =~ regex)
      end

      # Convert hash keys to symbols
      #
      # @param hash [Hash] Hash with string keys
      # @return [Hash] Hash with symbol keys
      def symbolize_keys(hash)
        return {} unless hash.is_a?(Hash)

        hash.each_with_object({}) do |(key, value), result|
          result[key.to_sym] = value
        end
      end
    end
  end
end