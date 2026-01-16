# frozen_string_literal: true

require "yaml"

module Lutaml
  module Ea
    module Diagram
      # Configuration management for diagram styling
      #
      # This class provides hierarchical style resolution with the
      # following priority:
      # 1. EA Data (QEA/XMI) - Highest priority
      # 2. Class-specific overrides (user config)
      # 3. Package-based styling (wildcard support)
      # 4. Stereotype-based styling
      # 5. Global defaults - Lowest priority
      #
      # @example
      #   config = Configuration.new("config/diagram_styles.yml")
      #   fill_color = config.style_for(element, "colors.fill")
      #   font_family = config.style_for(element, "fonts.class_name.family")
      class Configuration
        attr_reader :config_data

        # Default configuration file paths in order of preference
        DEFAULT_CONFIG_PATHS = [
          "config/diagram_styles.yml",
          File.expand_path("~/.lutaml/diagram_styles.yml"),
        ].freeze

        # Initialize configuration with optional custom path
        #
        # @param config_path [String, nil] Path to custom configuration file
        def initialize(config_path = nil)
          @config_data = load_configuration(config_path)
        end

        # Get style for a specific element
        #
        # @param element [Lutaml::Uml::Class, Object] UML element
        # @param property [String] Style property path (e.g., "colors.fill")
        # @return [Object] Style value
        def style_for(element, property) # rubocop:disable Metrics/AbcSize,Metrics/CyclomaticComplexity,Metrics/MethodLength,Metrics/PerceivedComplexity
          return nil if property.nil? || property.empty?

          # Priority: Class-specific > Package > Stereotype > Defaults
          value = nil

          # 1. Try class-specific override (highest priority)
          if element.respond_to?(:name) && element.name
            class_config = dig_config("classes.#{element.name}.#{property}")
            value = class_config if class_config
          end

          # 2. Try package-based styling
          if !value &&
              element.respond_to?(:package_name) && element.package_name
            # Support wildcards: "CityGML::*"
            package_configs = config_data["packages"] || {}
            package_configs.each do |pattern, pkg_config|
              if matches_package?(element.package_name, pattern)
                pkg_value = dig_hash(pkg_config, property)
                value = pkg_value if pkg_value
                break
              end
            end
          end

          # 3. Try stereotype-based styling
          if !value && element.respond_to?(:stereotype) && element.stereotype
            stereotypes = Array(element.stereotype)
            stereotypes.each do |stereo|
              stereo_value = dig_config("stereotypes.#{stereo}.#{property}")
              if stereo_value
                value = stereo_value
                break
              end
            end
          end

          # 4. Fall back to defaults (lowest priority)
          # Handle property name aliases
          # (e.g., "colors.fill" -> "colors.default_fill")
          unless value
            value = dig_config("defaults.#{property}")

            # If not found, try with "default_" prefix for certain properties
            unless value
              if property.start_with?("colors.fill")
                value = dig_config("defaults.colors.default_fill")
              elsif property.start_with?("colors.stroke") &&
                  !property.include?("stroke_")
                value = dig_config("defaults.colors.default_stroke")
              end
            end
          end

          value
        end

        # Get connector style
        #
        # @param connector_type [String]
        # Type of connector (generalization, association, etc.)
        # @param property [String] Style property path
        # @return [Object] Style value
        def connector_style(connector_type, property)
          dig_config("connectors.#{connector_type}.#{property}")
        end

        # Get legend configuration
        #
        # @return [Hash] Legend configuration
        def legend_config
          config_data["legend"] || {}
        end

        # Get the entire configuration data
        #
        # @return [Hash] Complete configuration data
        def to_h
          config_data
        end

        private

        # Load configuration from files
        #
        # @param custom_path [String, nil] Custom configuration path
        # @return [Hash] Merged configuration data
        def load_configuration(custom_path = nil) # rubocop:disable Metrics/MethodLength
          paths = custom_path ? [custom_path] : DEFAULT_CONFIG_PATHS
          merged_config = default_config

          paths.each do |path|
            next unless File.exist?(path)

            begin
              user_config = YAML.load_file(path)
              if user_config.is_a?(Hash)
                merged_config = deep_merge(merged_config,
                                           user_config)
              end
            rescue StandardError => e
              warn "Warning: Failed to load configuration from " \
                   "#{path}: #{e.message}"
            end
          end

          merged_config
        end

        def default_config # rubocop:disable Metrics/MethodLength
          # Built-in defaults (minimal, as fallback)
          {
            "defaults" => {
              "colors" => {
                "background" => "#FFFFFF",
                "default_fill" => "#E0E0E0",
                "default_stroke" => "#000000",
                "text" => "#000000",
              },
              "fonts" => {
                "default" => {
                  "family" => "Carlito, Arial, sans-serif",
                  "size" => 9,
                  "weight" => 400,
                  "style" => "normal",
                },
                "class_name" => {
                  "family" => "Carlito, Arial, sans-serif",
                  "size" => 9,
                  "weight" => 700,
                  "style" => "normal",
                },
                "stereotype" => {
                  "family" => "Carlito, Arial, sans-serif",
                  "size" => 9,
                  "weight" => 400,
                  "style" => "normal",
                },
              },
              "box" => {
                "stroke_width" => 2,
                "stroke_linecap" => "round",
                "stroke_linejoin" => "bevel",
                "corner_radius" => 0,
                "padding" => 5,
              },
              "text" => {
                "visibility_public" => "+",
                "visibility_private" => "-",
                "visibility_protected" => "#",
                "visibility_package" => "~",
                "cardinality_format" => "[%s]",
                "stereotype_format" => "«%s»",
              },
            },
            "stereotypes" => {
              "DataType" => {
                "colors" => {
                  "fill" => "#FFCCFF",
                  "stroke" => "#000000",
                },
                "fonts" => {
                  "class_name" => {
                    "weight" => 700,
                    "style" => "italic",
                  },
                },
              },
              "FeatureType" => {
                "colors" => {
                  "fill" => "#FFFFCC",
                  "stroke" => "#000000",
                },
              },
              "GMLType" => {
                "colors" => {
                  "fill" => "#CCFFCC",
                  "stroke" => "#000000",
                },
              },
              "Interface" => {
                "colors" => {
                  "fill" => "#FFFFEE",
                  "stroke" => "#000000",
                },
                "fonts" => {
                  "class_name" => {
                    "style" => "italic",
                  },
                },
              },
            },
            "connectors" => {
              "generalization" => {
                "arrow" => {
                  "type" => "hollow_triangle",
                  "size" => 10,
                },
                "line" => {
                  "stroke_width" => 1,
                  "stroke" => "#000000",
                },
              },
              "association" => {
                "arrow" => {
                  "type" => "open_arrow",
                  "size" => 8,
                },
                "line" => {
                  "stroke_width" => 1,
                  "stroke" => "#000000",
                },
                "labels" => {
                  "show_role_names" => true,
                  "show_cardinality" => true,
                  "font" => {
                    "family" => "Carlito, Arial, sans-serif",
                    "size" => 8,
                  },
                },
              },
              "dependency" => {
                "arrow" => {
                  "type" => "open_arrow",
                  "size" => 8,
                },
                "line" => {
                  "stroke_width" => 1,
                  "stroke" => "#000000",
                  "stroke_dasharray" => "5,5",
                },
              },
              "aggregation" => {
                "arrow" => {
                  "type" => "diamond",
                  "size" => 10,
                },
                "line" => {
                  "stroke_width" => 1,
                  "stroke" => "#000000",
                },
              },
              "composition" => {
                "arrow" => {
                  "type" => "filled_diamond",
                  "size" => 10,
                },
                "line" => {
                  "stroke_width" => 1,
                  "stroke" => "#000000",
                },
              },
            },
            "legend" => {
              "enabled" => true,
              "position" => "bottom_right",
              "title" => "Legend",
              "entries" => [
                {
                  "label" => "i-UR DataTypes",
                  "color" => "#FFCCFF",
                },
                {
                  "label" => "CityGML FeatureTypes",
                  "color" => "#FFFFCC",
                },
                {
                  "label" => "GML Types",
                  "color" => "#CCFFCC",
                },
              ],
            },
          }
        end

        # Navigate configuration using dot notation
        #
        # @param path [String] Configuration path (e.g., "colors.fill")
        # @return [Object] Configuration value
        def dig_config(path)
          dig_hash(config_data, path)
        end

        # Navigate hash using dot notation
        #
        # @param hash [Hash] Hash to navigate
        # @param path [String] Path with dot notation
        # @return [Object] Value at path
        def dig_hash(hash, path) # rubocop:disable Metrics/CyclomaticComplexity
          return nil if path.nil? || path.empty?
          return nil unless hash.is_a?(Hash)

          keys = path.split(".")
          return nil if keys.empty?

          keys.reduce(hash) do |h, key|
            return nil unless h.is_a?(Hash)

            h[key]
          end
        end

        # Check if package name matches pattern (supports wildcards)
        #
        # @param package_name [String] Package name to test
        # @param pattern [String] Pattern with wildcards (e.g., "CityGML::*")
        # @return [Boolean] True if matches
        def matches_package?(package_name, pattern)
          return false unless package_name && pattern

          # Support wildcards: "CityGML::*" matches "CityGML::Core"
          regex_pattern = pattern.gsub("*", ".*")
          Regexp.new("^#{regex_pattern}$").match?(package_name)
        rescue RegexpError => e
          warn "Warning: Invalid package pattern '#{pattern}': #{e.message}"
          false
        end

        # Deep merge two hashes
        #
        # @param hash1 [Hash] Base hash
        # @param hash2 [Hash] Hash to merge in
        # @return [Hash] Merged hash
        def deep_merge(hash1, hash2)
          hash1.merge(hash2) do |_key, old_val, new_val|
            if old_val.is_a?(Hash) && new_val.is_a?(Hash)
              deep_merge(old_val, new_val)
            else
              new_val
            end
          end
        end
      end
    end
  end
end