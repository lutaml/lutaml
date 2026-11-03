# frozen_string_literal: true

require "yaml"

module Lutaml
  module Xsd
    module Spa
      # Configuration loader for SPA documentation generator
      #
      # Loads and validates YAML configuration files for UI theme, features,
      # and templates. Provides type-safe access to configuration values with
      # defaults fallback.
      #
      # @example Load all configurations
      #   loader = ConfigurationLoader.new
      #   theme = loader.theme
      #   features = loader.features
      #   templates = loader.templates
      #
      # @example Load with custom config directory
      #   loader = ConfigurationLoader.new(config_dir: './custom/config')
      #   theme = loader.theme
      class ConfigurationLoader
        # Default configuration directory
        DEFAULT_CONFIG_DIR = File.expand_path(
          "../../../../config/spa",
          __dir__,
        )

        attr_reader :config_dir

        # Initialize configuration loader
        #
        # @param config_dir [String] Path to configuration directory
        def initialize(config_dir: DEFAULT_CONFIG_DIR)
          @config_dir = config_dir
          @cache = {}
        end

        # Load UI theme configuration
        #
        # @return [Hash] Theme configuration
        def theme
          load_config("ui_theme", default_theme)
        end
        alias load_ui_theme theme
        alias load_theme theme

        # Load features configuration
        #
        # @return [Hash] Features configuration
        def features
          load_config("features", default_features)
        end
        alias load_features features

        # Load templates configuration
        #
        # @return [Hash] Templates configuration
        def templates
          load_config("templates", default_templates)
        end
        alias load_templates templates

        # Get color value from theme
        #
        # @param key [String] Color key (e.g., "primary", "background_primary")
        # @param dark_mode [Boolean] Whether to use dark theme colors
        # @return [String] Color hex value
        def color(key, dark_mode: false)
          colors = if dark_mode
                     theme.dig("theme",
                               "dark_colors")
                   else
                     theme.dig("theme",
                               "colors")
                   end
          colors&.fetch(key, nil) || "#000000"
        end

        # Get typography value from theme
        #
        # @param key [String] Typography key
        # @return [String] Typography value
        def typography(key)
          theme.dig("theme", "typography", key)
        end

        # Get layout value from theme
        #
        # @param key [String] Layout key
        # @return [String] Layout value
        def layout(key)
          theme.dig("theme", "layout", key)
        end

        # Check if a feature is enabled
        #
        # @param feature [String] Feature name
        # @return [Boolean] True if feature is enabled
        def feature_enabled?(feature)
          features.dig("features", feature, "enabled") || false
        end

        # Get feature setting
        #
        # @param feature [String] Feature name
        # @param setting [String] Setting key
        # @param default [Object] Default value if not found
        # @return [Object] Setting value
        def feature_setting(feature, setting, default: nil)
          features.dig("features", feature, setting) || default
        end

        # Get template layout components
        #
        # @param layout_name [String] Layout name (default: "default")
        # @return [Array<String>] List of component names
        def template_components(layout_name: "default")
          templates.dig("templates", "layouts", layout_name, "components") || []
        end

        # Get partial template path
        #
        # @param partial_name [String] Partial name
        # @return [String, nil] Partial template path
        def partial_template(partial_name)
          templates.dig("templates", "partials", partial_name, "template")
        end

        # Reload all configurations (clears cache)
        #
        # @return [void]
        def reload!
          @cache.clear
        end

        private

        # Load configuration file
        #
        # @param name [String] Configuration file name (without extension)
        # @param default [Hash] Default configuration to use if file not found
        # @return [Hash] Loaded configuration
        def load_config(name, default)
          return @cache[name] if @cache.key?(name)

          config_path = File.join(config_dir, "#{name}.yml")

          config = if File.exist?(config_path)
                     YAML.load_file(config_path)
                   else
                     default
                   end

          @cache[name] = config
        rescue Psych::SyntaxError => e
          warn "Warning: Failed to parse #{name}.yml: #{e.message}"
          warn "Using default configuration for #{name}"
          @cache[name] = default
        end

        # Default theme configuration
        #
        # @return [Hash] Default theme
        def default_theme
          {
            "theme" => {
              "colors" => {
                "primary" => "#2563eb",
                "secondary" => "#64748b",
                "background_primary" => "#ffffff",
                "text_primary" => "#0f172a",
                "border_light" => "#e2e8f0",
              },
              "typography" => {
                "font_family" => "system-ui, sans-serif",
                "font_size_base" => "1rem",
                "line_height_normal" => "1.5",
              },
              "layout" => {
                "sidebar_width" => "280px",
                "header_height" => "64px",
                "max_width_xl" => "1280px",
              },
            },
          }
        end

        # Default features configuration
        #
        # @return [Hash] Default features
        def default_features
          {
            "features" => {
              "search" => { "enabled" => true },
              "filtering" => { "enabled" => true },
              "navigation" => { "enabled" => true },
              "documentation" => { "enabled" => true },
            },
          }
        end

        # Default templates configuration
        #
        # @return [Hash] Default templates
        def default_templates
          {
            "templates" => {
              "layout" => "default",
              "layouts" => {
                "default" => {
                  "components" => %w[head header navigation search content
                                     footer scripts],
                },
              },
              "partials" => {},
              "single_file" => {
                "embed_resources" => true,
                "inline_css" => true,
                "inline_js" => true,
              },
              "multi_file" => {
                "separate_resources" => true,
                "directories" => {
                  "css" => "css",
                  "js" => "js",
                  "data" => "data",
                },
              },
            },
          }
        end
      end
    end
  end
end
