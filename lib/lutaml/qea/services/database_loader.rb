# frozen_string_literal: true

require_relative "../database"
require_relative "../infrastructure/database_connection"
require_relative "../infrastructure/table_reader"
require_relative "configuration"
require_relative "../models/ea_object"
require_relative "../models/ea_attribute"
require_relative "../models/ea_operation"
require_relative "../models/ea_operation_param"
require_relative "../models/ea_connector"
require_relative "../models/ea_package"
require_relative "../models/ea_diagram"
require_relative "../models/ea_diagram_object"
require_relative "../models/ea_diagram_link"
require_relative "../models/ea_object_constraint"
require_relative "../models/ea_tagged_value"
require_relative "../models/ea_object_property"
require_relative "../models/ea_attribute_tag"
require_relative "../models/ea_xref"
require_relative "../models/ea_document"
require_relative "../models/ea_script"
require_relative "../models/ea_stereotype"
require_relative "../models/ea_datatype"
require_relative "../models/ea_constraint_type"
require_relative "../models/ea_connector_type"
require_relative "../models/ea_diagram_type"
require_relative "../models/ea_object_type"
require_relative "../models/ea_status_type"
require_relative "../models/ea_complexity_type"

module Lutaml
  module Qea
    module Services
      # DatabaseLoader orchestrates loading all EA tables into a Database
      #
      # This service loads all enabled tables from the QEA database,
      # converts database rows to model instances, and populates a
      # Database container with the results.
      #
      # @example Load a database
      #   loader = DatabaseLoader.new("model.qea")
      #   loader.on_progress do |table, current, total|
      #     puts "Loading #{table}: #{current}/#{total}"
      #   end
      #   database = loader.load
      #
      # @example Load a single table
      #   loader = DatabaseLoader.new("model.qea")
      #   objects = loader.load_table("t_object")
      class DatabaseLoader
        # @return [String] Path to QEA file
        attr_reader :qea_path

        # @return [Configuration] Configuration instance
        attr_reader :config

        # Table name to model class mapping
        MODEL_CLASSES = {
          "t_object" => Models::EaObject,
          "t_attribute" => Models::EaAttribute,
          "t_operation" => Models::EaOperation,
          "t_operationparams" => Models::EaOperationParam,
          "t_connector" => Models::EaConnector,
          "t_package" => Models::EaPackage,
          "t_diagram" => Models::EaDiagram,
          "t_diagramobjects" => Models::EaDiagramObject,
          "t_diagramlinks" => Models::EaDiagramLink,
          "t_objectconstraint" => Models::EaObjectConstraint,
          "t_taggedvalue" => Models::EaTaggedValue,
          "t_objectproperties" => Models::EaObjectProperty,
          "t_attributetag" => Models::EaAttributeTag,
          "t_xref" => Models::EaXref,
          "t_document" => Models::EaDocument,
          "t_script" => Models::EaScript,
          "t_stereotypes" => Models::EaStereotype,
          "t_datatypes" => Models::EaDatatype,
          "t_constrainttypes" => Models::EaConstraintType,
          "t_connectortypes" => Models::EaConnectorType,
          "t_diagramtypes" => Models::EaDiagramType,
          "t_objecttypes" => Models::EaObjectType,
          "t_statustypes" => Models::EaStatusType,
          "t_complexitytypes" => Models::EaComplexityType,
        }.freeze

        # Initialize loader
        #
        # @param qea_path [String] Path to QEA file
        # @param config [Configuration, nil] Optional configuration
        def initialize(qea_path, config = nil)
          @qea_path = qea_path
          @config = config || Configuration.load
          @progress_callback = nil
          @connection = Infrastructure::DatabaseConnection.new(qea_path)
        end

        # Set progress callback
        #
        # @yield [table_name, current, total] Progress information
        # @yieldparam table_name [String] Current table being loaded
        # @yieldparam current [Integer] Records loaded so far
        # @yieldparam total [Integer] Total records in table
        # @return [self]
        def on_progress(&block)
          @progress_callback = block
          self
        end

        # Load entire database
        #
        # @return [Database] Populated database instance
        # @raise [Errno::ENOENT] if QEA file not found
        # @raise [SQLite3::Exception] if database access fails
        def load
          # Connect but don't use with_connection - we need to keep it open
          @connection.connect unless @connection.connected?
          db = @connection.connection

          database = Database.new(@qea_path, db)

          @config.enabled_tables.each do |table_def|
            table_name = table_def.table_name
            collection_name = table_def.collection_name

            records = load_table_records(db, table_name)
            database.add_collection(collection_name, records)
          end

          database.freeze
        end

        # Load a single table
        #
        # @param table_name [String] Table name to load
        # @return [Array] Array of model instances
        # @raise [ArgumentError] if table not configured or not enabled
        def load_table(table_name)
          table_def = @config.table_config_for(table_name)
          unless table_def
            raise ArgumentError,
                  "Table #{table_name} not configured"
          end
          unless table_def.enabled
            raise ArgumentError,
                  "Table #{table_name} not enabled"
          end

          @connection.with_connection do |db|
            load_table_records(db, table_name)
          end
        end

        # Get quick statistics without full loading
        #
        # @return [Hash<String, Integer>] Table names to record counts
        def quick_stats
          stats = {}

          @connection.with_connection do |db|
            @config.enabled_tables.each do |table_def|
              reader = Infrastructure::TableReader.new(db, table_def.table_name)
              stats[table_def.collection_name] = reader.count
            end
          end

          stats
        end

        private

        # Load records for a table
        #
        # @param db [SQLite3::Database] Database connection
        # @param table_name [String] Table name
        # @return [Array] Array of model instances
        def load_table_records(db, table_name)
          model_class = MODEL_CLASSES[table_name]
          unless model_class
            raise ArgumentError, "No model class for table #{table_name}"
          end

          reader = Infrastructure::TableReader.new(db, table_name)
          total = reader.count
          records = []

          rows = reader.all
          rows.each_with_index do |row, index|
            record = model_class.from_db_row(row)
            records << record if record
            if @progress_callback
              report_progress(table_name, index + 1,
                              total)
            end
          rescue StandardError => e
            # Log error but continue loading other records
            warn "Error loading record from #{table_name}: #{e.message}"
          end

          records
        end

        # Report progress to callback
        #
        # @param table_name [String] Current table
        # @param current [Integer] Current record count
        # @param total [Integer] Total records
        def report_progress(table_name, current, total)
          @progress_callback.call(table_name, current, total)
        rescue StandardError => e
          warn "Error in progress callback: #{e.message}"
        end
      end
    end
  end
end
