# frozen_string_literal: true

require "lutaml/model"
require "yaml"

module Lutaml
  module UmlRepository
    module StaticSite
      # Configuration for Static Site Generator using external YAML.
      #
      # Follows the Dependency Inversion Principle by externalizing all
      # configuration instead of hardcoding values. Uses lutaml-model for
      # structured YAML parsing and validation.
      #
      # @example Load configuration
      #   config = Configuration.load
      #
      # @example Load custom configuration
      #   config = Configuration.load("my_config.yml")
      class Configuration < Lutaml::Model::Serializable
        # Output mode configuration
        class OutputMode < Lutaml::Model::Serializable
          attribute :enabled, :boolean, default: -> { true }
          attribute :default_filename, :string
          attribute :default_directory, :string
          attribute :embed_data, :boolean
          attribute :embed_styles, :boolean
          attribute :embed_scripts, :boolean
          attribute :data_directory, :string
          attribute :assets_directory, :string
          attribute :minify, :boolean, default: -> { false }

          yaml do
            map "enabled", to: :enabled
            map "default_filename", to: :default_filename
            map "default_directory", to: :default_directory
            map "embed_data", to: :embed_data
            map "embed_styles", to: :embed_styles
            map "embed_scripts", to: :embed_scripts
            map "data_directory", to: :data_directory
            map "assets_directory", to: :assets_directory
            map "minify", to: :minify
          end
        end

        # Output configuration container
        class OutputConfig < Lutaml::Model::Serializable
          attribute :modes, :string # Will be parsed as hash

          yaml do
            map "modes", to: :modes
          end

          def single_file
            @single_file ||= parse_mode_config(modes["single_file"]) if modes
          end

          def multi_file
            @multi_file ||= parse_mode_config(modes["multi_file"]) if modes
          end

          private

          def parse_mode_config(config_hash)
            return nil unless config_hash

            OutputMode.new.tap do |mode|
              mode.enabled = config_hash["enabled"]
              mode.default_filename = config_hash["default_filename"]
              mode.default_directory = config_hash["default_directory"]
              mode.embed_data = config_hash["embed_data"]
              mode.embed_styles = config_hash["embed_styles"]
              mode.embed_scripts = config_hash["embed_scripts"]
              mode.data_directory = config_hash["data_directory"]
              mode.assets_directory = config_hash["assets_directory"]
              mode.minify = config_hash["minify"]
            end
          end
        end

        # Search field configuration
        class SearchField < Lutaml::Model::Serializable
          attribute :name, :string
          attribute :boost, :integer, default: -> { 1 }
          attribute :searchable, :boolean, default: -> { true }

          yaml do
            map "name", to: :name
            map "boost", to: :boost
            map "searchable", to: :searchable
          end
        end

        # Document type configuration
        class DocumentType < Lutaml::Model::Serializable
          attribute :type, :string
          attribute :boost, :float, default: -> { 1.0 }
          attribute :enabled, :boolean, default: -> { true }

          yaml do
            map "type", to: :type
            map "boost", to: :boost
            map "enabled", to: :enabled
          end
        end

        # Search configuration
        class SearchConfig < Lutaml::Model::Serializable
          attribute :enabled, :boolean, default: -> { true }
          attribute :fields, SearchField, collection: true
          attribute :document_types, DocumentType, collection: true
          attribute :stop_words, :string, collection: true
          attribute :pipeline, :string, collection: true

          yaml do
            map "enabled", to: :enabled
            map "fields", to: :fields
            map "document_types", to: :document_types
            map "stop_words", to: :stop_words
            map "pipeline", to: :pipeline
          end
        end

        # UI configuration
        class UIConfig < Lutaml::Model::Serializable
          attribute :title, :string
          attribute :description, :string
          attribute :theme, :string # Will be parsed as hash
          attribute :sidebar, :string # Will be parsed as hash
          attribute :breadcrumb, :string  # Will be parsed as hash
          attribute :statistics, :string  # Will be parsed as hash

          yaml do
            map "title", to: :title
            map "description", to: :description
            map "theme", to: :theme
            map "sidebar", to: :sidebar
            map "breadcrumb", to: :breadcrumb
            map "statistics", to: :statistics
          end
        end

        # Main configuration attributes
        attribute :version, :string
        attribute :description, :string
        attribute :output, OutputConfig
        attribute :templates, :string # Will be hash
        attribute :data_transformation, :string # Will be hash
        attribute :search, SearchConfig
        attribute :assets, :string # Will be hash
        attribute :ui, UIConfig
        attribute :features, :string # Will be hash
        attribute :plugins, :string # Will be hash
        attribute :performance, :string # Will be hash
        attribute :accessibility, :string # Will be hash

        yaml do
          map "version", to: :version
          map "description", to: :description
          map "output", to: :output
          map "templates", to: :templates
          map "data_transformation", to: :data_transformation
          map "search", to: :search
          map "assets", to: :assets
          map "ui", to: :ui
          map "features", to: :features
          map "plugins", to: :plugins
          map "performance", to: :performance
          map "accessibility", to: :accessibility
        end

        class << self
          # Load configuration from YAML file
          #
          # @param config_path [String, nil] Path to configuration file
          # @return [Configuration] Loaded configuration
          def load(config_path = nil)
            config_path ||= default_config_path

            unless File.exist?(config_path)
              return create_default_configuration
            end

            yaml_content = File.read(config_path)
            from_yaml(yaml_content)
          end

          # Get default configuration file path
          #
          # @return [String] Path to default config
          def default_config_path
            File.expand_path("../../../../config/static_site.yml", __dir__)
          end

          # Create default configuration programmatically
          #
          # @return [Configuration] Default configuration
          def create_default_configuration
            new.tap do |config|
              config.version = "1.0"
              config.description = "Default Static Site Configuration"
            end
          end
        end

        # Get data transformation options as hash
        #
        # @return [Hash] Transformation options
        def transformation_options
          @transformation_options ||= parse_hash_attribute(data_transformation)
        end

        # Get features as hash
        #
        # @return [Hash] Feature flags
        def feature_flags
          @feature_flags ||= parse_hash_attribute(features)
        end

        # Check if a feature is enabled
        #
        # @param feature_name [String, Symbol] Feature name
        # @return [Boolean] true if feature is enabled
        def feature_enabled?(feature_name)
          feature_flags[feature_name.to_s] == true
        end

        private

        def parse_hash_attribute(attr)
          case attr
          when Hash
            attr
          when String
            begin
              YAML.safe_load(attr)
            rescue StandardError
              {}
            end
          else
            {}
          end
        end
      end
    end
  end
end
