# frozen_string_literal: true

require "yaml"

module Lutaml
  module UmlRepository
    # Configuration management for LutaML XMI operations.
    #
    # Provides persistent configuration storage for XMI/LUR workflows including:
    # - Default serialization format (marshal or yaml)
    # - Default base path for relative file operations
    # - Recent packages tracking for quick access
    # - Package aliases for convenient references
    # - UI preferences (colorize, progress bars, etc.)
    #
    # Configuration is stored in `.lutaml-xmi.yaml` in the project root.
    #
    # @example Loading configuration
    #   config = Configuration.load
    #   puts config.default_format  # => :marshal
    #
    # @example Saving configuration
    #   config = Configuration.new
    #   config.default_format = :yaml
    #   config.save
    #
    # @example Using aliases
    #   config.add_alias("my-model", "path/to/model.lur")
    #   path = config.resolve_alias("@my-model")
    class Configuration
      # Default configuration filename
      CONFIG_FILENAME = ".lutaml-uml-repository.yaml"

      # @return [Symbol] Default serialization format (:marshal or :yaml)
      attr_accessor :default_format

      # @return [String] Default base path for relative file operations
      attr_accessor :default_base_path

      # @return [Array<String>] Recently used package paths
      attr_reader :recent_packages

      # @return [Hash{String => String}] Package aliases mapping
      attr_reader :package_aliases

      # @return [Hash] UI preferences
      attr_reader :ui_preferences

      # Initialize a new Configuration instance.
      #
      # @param attributes [Hash] Initial attributes
      # @option attributes [Symbol] :default_format (:marshal) Serialization format
      # @option attributes [String] :default_base_path (Dir.pwd) Base path
      # @option attributes [Array<String>] :recent_packages ([]) Recent packages
      # @option attributes [Hash] :package_aliases ({}) Package aliases
      # @option attributes [Hash] :ui_preferences ({}) UI preferences
      def initialize(attributes = {})
        @default_format = attributes[:default_format] || :marshal
        @default_base_path = attributes[:default_base_path] || Dir.pwd
        @recent_packages = attributes[:recent_packages] || []
        @package_aliases = attributes[:package_aliases] || {}
        @ui_preferences = attributes[:ui_preferences] || default_ui_preferences
      end

      # Load configuration from a directory.
      #
      # Looks for `.lutaml-xmi.yaml` in the specified directory. If not found,
      # returns a new configuration with default values.
      #
      # @param directory [String] Directory to load from (default: current directory)
      # @return [Configuration] Loaded or default configuration
      # @example
      #   config = Configuration.load
      #   config = Configuration.load("/path/to/project")
      def self.load(directory = ".")
        config_path = File.join(directory, CONFIG_FILENAME)

        if File.exist?(config_path)
          data = YAML.load_file(config_path)
          new(
            default_format: data["default_format"]&.to_sym || :marshal,
            default_base_path: data["default_base_path"] || Dir.pwd,
            recent_packages: data["recent_packages"] || [],
            package_aliases: data["package_aliases"] || {},
            ui_preferences: data["ui_preferences"] || {},
          )
        else
          new
        end
      end

      # Save configuration to a directory.
      #
      # Writes configuration to `.lutaml-xmi.yaml` in the specified directory.
      #
      # @param directory [String] Directory to save to (default: current directory)
      # @return [void]
      # @example
      #   config.save
      #   config.save("/path/to/project")
      def save(directory = ".")
        config_path = File.join(directory, CONFIG_FILENAME)

        data = {
          "default_format" => @default_format.to_s,
          "default_base_path" => @default_base_path,
          "recent_packages" => @recent_packages,
          "package_aliases" => @package_aliases,
          "ui_preferences" => @ui_preferences,
        }

        File.write(config_path, YAML.dump(data))
      end

      # Resolve an alias to its full path.
      #
      # If the input starts with '@', treats it as an alias and looks it up.
      # Otherwise, returns the input unchanged.
      #
      # @param alias_or_path [String] Alias (e.g., "@my-model") or path
      # @return [String, nil] Resolved path, or nil if alias not found
      # @example
      #   config.add_alias("model", "/path/to/model.lur")
      #   config.resolve_alias("@model")  # => "/path/to/model.lur"
      #   config.resolve_alias("direct/path.lur")  # => "direct/path.lur"
      def resolve_alias(alias_or_path)
        return alias_or_path unless alias_or_path.start_with?("@")

        alias_name = alias_or_path[1..]
        @package_aliases[alias_name]
      end

      # Add or update a package alias.
      #
      # @param alias_name [String] Alias name (without '@' prefix)
      # @param package_path [String] Full path to package
      # @return [void]
      # @example
      #   config.add_alias("my-model", "/path/to/model.lur")
      def add_alias(alias_name, package_path)
        @package_aliases[alias_name] = package_path
      end

      # Remove a package alias.
      #
      # @param alias_name [String] Alias name to remove
      # @return [void]
      # @example
      #   config.remove_alias("my-model")
      def remove_alias(alias_name)
        @package_aliases.delete(alias_name)
      end

      # Add a package to the recent packages list.
      #
      # Adds the package to the front of the list and limits to 10 most recent.
      # Removes duplicates by moving existing entries to the front.
      #
      # @param package_path [String] Path to package
      # @return [void]
      # @example
      #   config.add_recent("/path/to/model.lur")
      def add_recent(package_path)
        @recent_packages.delete(package_path)
        @recent_packages.unshift(package_path)
        @recent_packages = @recent_packages.take(10)
      end

      # Clear all recent packages.
      #
      # @return [void]
      # @example
      #   config.clear_recent
      def clear_recent
        @recent_packages.clear
      end

      # Set a UI preference.
      #
      # @param key [String, Symbol] Preference key
      # @param value [Object] Preference value
      # @return [void]
      # @example
      #   config.set_ui_preference(:colorize, false)
      def set_ui_preference(key, value)
        @ui_preferences[key.to_s] = value
      end

      # Get a UI preference.
      #
      # @param key [String, Symbol] Preference key
      # @param default [Object] Default value if not set
      # @return [Object] Preference value
      # @example
      #   colorize = config.get_ui_preference(:colorize, true)
      def get_ui_preference(key, default = nil)
        @ui_preferences.fetch(key.to_s, default)
      end

      private

      # Get default UI preferences.
      #
      # @return [Hash] Default UI preferences
      def default_ui_preferences
        {
          "colorize" => true,
          "progress_bars" => true,
          "verbose" => false,
          "compact_output" => false,
        }
      end
    end
  end
end