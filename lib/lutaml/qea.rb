# frozen_string_literal: true

require_relative "qea/infrastructure/database_connection"
require_relative "qea/infrastructure/schema_reader"
require_relative "qea/infrastructure/table_reader"
require_relative "qea/services/configuration"
require_relative "qea/services/database_loader"
require_relative "qea/database"
require_relative "qea/factory/ea_to_uml_factory"
require_relative "qea/validation/validation_message"
require_relative "qea/validation/validation_result"
require_relative "qea/validation/base_validator"
require_relative "qea/validation/validator_registry"
require_relative "qea/validation/validation_engine"

module Lutaml
  # QEA module provides direct SQLite database parsing for Enterprise Architect
  # .qea files, bypassing XMI for better performance and access to EA-specific
  # metadata.
  #
  # This is the main public API for working with QEA files.
  #
  # @example Connect and read schema
  #   conn = Lutaml::Qea::Infrastructure::DatabaseConnection.new("model.qea")
  #   conn.with_connection do |db|
  #     reader = Lutaml::Qea::Infrastructure::SchemaReader.new(db)
  #     puts reader.tables
  #   end
  #
  # @example Load configuration
  #   config = Lutaml::Qea::Services::Configuration.load
  #   puts config.enabled_tables.map(&:table_name)
  module Qea
    # QEA Parser version
    VERSION = "0.1.0"

    class << self
      # Get the current configuration
      #
      # @return [Services::Configuration] The loaded configuration
      def configuration
        @configuration ||= Services::Configuration.load
      end

      # Set a custom configuration
      #
      # @param config [Services::Configuration] The configuration to use
      def configuration=(config)
        @configuration = config
      end

      # Reload configuration from file
      #
      # @param config_path [String, nil] Optional custom config path
      # @return [Services::Configuration] The reloaded configuration
      def reload_configuration(config_path = nil)
        @configuration = Services::Configuration.load(config_path)
      end

      # Connect to a QEA file
      #
      # @param file_path [String] Path to the .qea file
      # @return [Infrastructure::DatabaseConnection] The connection object
      #
      # @example
      #   conn = Qea.connect("model.qea")
      #   conn.with_connection do |db|
      #     # Use db
      #   end
      def connect(file_path)
        Infrastructure::DatabaseConnection.new(file_path)
      end

      # Open a QEA file and yield the connection
      #
      # @param file_path [String] Path to the .qea file
      # @yield [Infrastructure::DatabaseConnection] The connection object
      # @return [Object] The result of the block
      #
      # @example
      #   Qea.open("model.qea") do |conn|
      #     conn.with_connection do |db|
      #       reader = Qea::Infrastructure::SchemaReader.new(db)
      #       puts reader.tables
      #     end
      #   end
      def open(file_path)
        connection = connect(file_path)
        yield connection
      ensure
        connection&.close if connection&.connected?
      end

      # Get schema information from a QEA file
      #
      # @param file_path [String] Path to the .qea file
      # @return [Hash] Schema information including tables and row counts
      #
      # @example
      #   info = Qea.schema_info("model.qea")
      #   puts info[:tables]
      #   puts info[:statistics]
      def schema_info(file_path)
        connection = connect(file_path)
        connection.with_connection do |db|
          reader = Infrastructure::SchemaReader.new(db)
          {
            tables: reader.tables,
            statistics: reader.statistics,
          }
        end
      ensure
        connection&.close if connection&.connected?
      end

      # Load complete database with all tables and models
      #
      # @param qea_path [String] Path to the .qea file
      # @param config [Services::Configuration, nil] Optional custom configuration
      # @return [Database] Loaded database with all collections
      #
      # @example Load database
      #   database = Qea.load_database("model.qea")
      #   puts database.stats
      #   # => {"objects" => 693, "attributes" => 1910, ...}
      #
      # @example With progress callback
      #   database = Qea.load_database("model.qea") do |table, current, total|
      #     puts "Loading #{table}: #{current}/#{total}"
      #   end
      def load_database(qea_path, config = nil, &progress_callback)
        loader = Services::DatabaseLoader.new(qea_path, config)
        loader.on_progress(&progress_callback) if progress_callback
        loader.load
      end

      # Get quick database statistics without full loading
      #
      # @param qea_path [String] Path to the .qea file
      # @param config [Services::Configuration, nil] Optional custom configuration
      # @return [Hash<String, Integer>] Collection names to record counts
      #
      # @example
      #   info = Qea.database_info("model.qea")
      #   puts info
      #   # => {"objects" => 693, "attributes" => 1910, ...}
      def database_info(qea_path, config = nil)
        loader = Services::DatabaseLoader.new(qea_path, config)
        loader.quick_stats
      end

      # Parse QEA file to complete UML Document
      #
      # @param qea_path [String] Path to the .qea file
      # @param options [Hash] Transformation options
      # @option options [Boolean] :include_diagrams Include diagrams (default: true)
      # @option options [Boolean] :validate Validate during parsing (default: false)
      # @option options [String] :document_name Document name
      # @option options [Services::Configuration] :config Custom configuration
      # @return [Lutaml::Uml::Document, Hash] Document, or hash with :document and :validation_result
      #
      # @example Parse QEA file
      #   document = Lutaml::Qea.parse("model.qea")
      #   puts "Packages: #{document.packages.size}"
      #   puts "Classes: #{document.classes.size}"
      #   puts "Associations: #{document.associations.size}"
      #
      # @example Parse with validation
      #   result = Lutaml::Qea.parse("model.qea", validate: true)
      #   document = result[:document]
      #   validation = result[:validation_result]
      #   puts validation.summary
      #
      # @example Use with UmlRepository
      #   document = Lutaml::Qea.parse("model.qea")
      #   repo = Lutaml::UmlRepository::Repository.new(document: document)
      #   results = repo.search("Building")
      #   puts "Found #{results[:total]} matches"
      def parse(qea_path, options = {})
        # Extract config and validation options
        config = options.delete(:config)
        validate = options.delete(:validate)

        # Load database (connection stays open)
        loader = Services::DatabaseLoader.new(qea_path, config)
        ea_database = loader.load

        begin
          # Create and execute factory
          factory = Factory::EaToUmlFactory.new(ea_database, options)
          document = factory.create_document

          # Run validation if requested
          if validate
            engine = Validation::ValidationEngine.new(
              document,
              database: ea_database,
              **options,
            )
            validation_result = engine.validate

            {
              document: document,
              validation_result: validation_result,
            }
          else
            document
          end
        ensure
          # Close the connection when done (unless validation needs it)
          if !validate && ea_database.connection && !ea_database.connection.closed?
            ea_database.connection&.close
          end
        end
      end
    end
  end
end
