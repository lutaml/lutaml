# frozen_string_literal: true

require "lutaml/model"
require "yaml"

module Lutaml
  module Qea
    module Services
      # Configuration service loads and provides configuration from YAML file.
      #
      # This service uses lutaml-model for YAML parsing and provides access to
      # QEA schema configuration including table definitions, type mappings,
      # and transformation rules.
      #
      # @example Load configuration
      #   config = Configuration.load
      #   tables = config.enabled_tables
      #
      # @example Get table configuration
      #   table_cfg = config.table_config_for("t_object")
      class Configuration < Lutaml::Model::Serializable
        # Column definition model
        class ColumnDefinition < Lutaml::Model::Serializable
          attribute :name, :string
          attribute :type, :string
          attribute :primary, :boolean, default: -> { false }
          attribute :nullable, :boolean, default: -> { true }
          attribute :boolean, :boolean, default: -> { false }
          attribute :default, :string

          yaml do
            map "name", to: :name
            map "type", to: :type
            map "primary", to: :primary
            map "nullable", to: :nullable
            map "boolean", to: :boolean
            map "default", to: :default
          end
        end

        # Table definition model
        class TableDefinition < Lutaml::Model::Serializable
          attribute :table_name, :string
          attribute :enabled, :boolean, default: -> { true }
          attribute :primary_key, :string
          attribute :collection_name, :string
          attribute :description, :string
          attribute :columns, ColumnDefinition, collection: true

          yaml do
            map "table_name", to: :table_name
            map "enabled", to: :enabled
            map "primary_key", to: :primary_key
            map "collection_name", to: :collection_name
            map "description", to: :description
            map "columns", to: :columns
          end

          # Get column definition by name
          #
          # @param column_name [String] The column name
          # @return [ColumnDefinition, nil] The column definition or nil
          def column_for(column_name)
            columns&.find { |col| col.name == column_name }
          end

          # Check if a column is boolean type
          #
          # @param column_name [String] The column name
          # @return [Boolean] true if column should be treated as boolean
          def boolean_column?(column_name)
            col = column_for(column_name)
            col&.boolean == true
          end
        end

        # Null handling configuration model
        class NullHandling < Lutaml::Model::Serializable
          attribute :strategy, :string
          attribute :empty_string_as_null, :boolean, default: -> { true }
          attribute :zero_as_null, :boolean, default: -> { false }

          yaml do
            map "strategy", to: :strategy
            map "empty_string_as_null", to: :empty_string_as_null
            map "zero_as_null", to: :zero_as_null
          end
        end

        attribute :version, :string
        attribute :description, :string
        attribute :type_mappings, :string, collection: true
        attribute :boolean_fields, :string, collection: true
        attribute :null_handling, NullHandling
        attribute :tables, TableDefinition, collection: true

        yaml do
          map "version", to: :version
          map "description", to: :description
          map "type_mappings", to: :type_mappings
          map "boolean_fields", to: :boolean_fields
          map "null_handling", to: :null_handling
          map "tables", to: :tables
        end

        class << self
          # Load configuration from YAML file
          #
          # @param config_path [String, nil] Path to configuration file
          #   Defaults to config/qea_schema.yml
          # @return [Configuration] The loaded configuration
          # @raise [Errno::ENOENT] if config file not found
          # @raise [Lutaml::Model::Error] if YAML is invalid
          def load(config_path = nil)
            config_path ||= default_config_path

            unless File.exist?(config_path)
              raise Errno::ENOENT,
                    "Configuration file not found: #{config_path}"
            end

            yaml_content = File.read(config_path)
            from_yaml(yaml_content)
          end

          # Get default configuration file path
          #
          # @return [String] Path to default config file
          def default_config_path
            File.expand_path("../../../../config/qea_schema.yml", __dir__)
          end
        end

        # Get list of enabled tables
        #
        # @return [Array<TableDefinition>] Array of enabled table definitions
        def enabled_tables
          tables&.select(&:enabled) || []
        end

        # Get table configuration by table name
        #
        # @param table_name [String] The table name
        # @return [TableDefinition, nil] The table definition
        # or nil if not found
        def table_config_for(table_name)
          tables&.find { |t| t.table_name == table_name }
        end

        # Check if a table is enabled
        #
        # @param table_name [String] The table name
        # @return [Boolean] true if table is enabled
        def table_enabled?(table_name)
          table = table_config_for(table_name)
          table&.enabled == true
        end

        # Get all enabled table names
        #
        # @return [Array<String>] Array of enabled table names
        def enabled_table_names
          enabled_tables.map(&:table_name)
        end

        # Check if a field should be treated as boolean
        #
        # @param field_name [String] The field name
        # @return [Boolean] true if field is in boolean_fields list
        def boolean_field?(field_name)
          boolean_fields&.include?(field_name) || false
        end

        # Get primary key for a table
        #
        # @param table_name [String] The table name
        # @return [String, nil] The primary key column name
        def primary_key_for(table_name)
          table = table_config_for(table_name)
          table&.primary_key
        end

        # Get collection name for a table
        #
        # @param table_name [String] The table name
        # @return [String, nil] The collection name
        def collection_name_for(table_name)
          table = table_config_for(table_name)
          table&.collection_name
        end

        # Convert empty strings to nil based on configuration
        #
        # @param value [String, nil] The value to convert
        # @return [String, nil] The converted value
        def convert_empty_string(value)
          return value unless null_handling&.empty_string_as_null

          value.nil? || value.empty? ? nil : value
        end

        # Check if zero should be treated as null
        #
        # @return [Boolean] true if zero should be converted to nil
        def zero_as_null?
          null_handling&.zero_as_null == true
        end
      end
    end
  end
end
