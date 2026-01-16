# frozen_string_literal: true

require_relative "base_parser"
require_relative "../../qea"

module Lutaml
  module ModelTransformations
    module Parsers
      # QEA Parser implements the BaseParser interface for Enterprise Architect
      # database files.
      #
      # This parser wraps the existing Lutaml::Qea functionality and adapts it
      # to the new unified transformation architecture. It provides enhanced
      # error handling, progress tracking, and configuration integration.
      class QeaParser < BaseParser
        # @return [Lutaml::Qea::Database] Loaded QEA database
        attr_reader :qea_database

        # @return [Hash] Database statistics
        attr_reader :database_stats

        # Get parser format name
        #
        # @return [String] Human-readable format name
        def format_name
          "Enterprise Architect Database (QEA)"
        end

        # Get list of supported file extensions
        #
        # @return [Array<String>] List of extensions
        def supported_extensions
          [".qea", ".eap", ".eapx"]
        end

        def content_patterns
          [/^SQLite format/]
        end

        def priority
          90
        end

        protected

        # Core parsing implementation for QEA files
        #
        # @param file_path [String] Path to the QEA file
        # @return [Lutaml::Uml::Document] Parsed UML document
        def parse_internal(file_path)
          # Validate QEA file format
          validate_qea_format!(file_path)

          # Load QEA database with progress tracking
          @qea_database = load_qea_database(file_path)

          # Get database statistics
          @database_stats = @qea_database.stats

          # Transform to UML document using existing factory
          document = transform_qea_to_uml(@qea_database, file_path)

          # Post-process document
          post_process_qea_document(document, file_path)

          document
        end

        # Hook called before parsing starts
        #
        # @param file_path [String] Path to the file being parsed
        # @return [void]
        def before_parse(file_path) # rubocop:disable Metrics/MethodLength
          add_info("Starting QEA parsing for: #{file_path}")

          # Check file size and provide estimates
          file_size = File.size(file_path)
          add_info("QEA file size: #{format_file_size(file_size)}")

          if file_size > 500 * 1024 * 1024 # 500MB
            add_warning("Very large QEA file detected, " \
                        "parsing may take significant time")
          end

          # Quick database info check
          begin
            quick_stats = get_quick_database_stats(file_path)
            add_info("Database contains approximately: " \
                     "#{format_database_stats(quick_stats)}")
          rescue StandardError => e
            add_warning("Could not get quick database stats: #{e.message}")
          end
        end

        # Hook called after parsing completes
        #
        # @param document [Lutaml::Uml::Document] Parsed document
        # @param file_path [String] Path to the source file
        # @return [Lutaml::Uml::Document] Processed document
        def after_parse(document, file_path)
          # Add QEA-specific metadata
          add_qea_metadata(document, file_path)

          # Validate QEA-specific aspects
          if @options[:validate_transformation]
            validate_qea_transformation(document)
          end

          # Add comprehensive statistics
          add_transformation_statistics(document)

          document
        end

        # Get default parsing options for QEA
        #
        # @return [Hash] Default options hash
        def default_options
          super.merge(
            include_diagrams: true,
            validate_transformation: false,
            load_progress_callback: true,
            cache_database: false,
            strict_schema_validation: false,
          )
        end

        private

        # Validate QEA file format
        #
        # @param file_path [String] Path to validate
        # @raise [ParseError] if file is not valid QEA
        def validate_qea_format!(file_path) # rubocop:disable Metrics/AbcSize,Metrics/MethodLength
          # Check if it's a SQLite database (QEA files are SQLite)
          File.open(file_path, "rb") do |file|
            header = file.read(16)

            unless header == "SQLite format 3\0"
              add_error("File does not appear to be a SQLite database")
              raise Parsers::ParseError.new("Invalid QEA format - " \
                                            "not a SQLite database")
            end
          end

          # Additional validation using QEA infrastructure
          begin
            Lutaml::Qea.connect(file_path).with_connection do |db|
              # Check for required EA tables
              required_tables = %w[t_object t_package t_connector t_attribute]
              missing_tables = required_tables.reject do |table|
                db.execute(
                  "SELECT name FROM sqlite_master " \
                  "WHERE type='table' AND name=?", table
                ).any?
              end

              if missing_tables.any?
                add_warning("Missing expected EA tables: " \
                            "#{missing_tables.join(', ')}")
              end
            end
          rescue StandardError => e
            add_error("Failed to validate QEA database structure: #{e.message}")
            raise Parsers::ParseError.new("QEA validation failed",
                                          original_error: e)
          end
        end

        # Load QEA database with progress tracking
        #
        # @param file_path [String] Path to QEA file
        # @return [Lutaml::Qea::Database] Loaded database
        def load_qea_database(file_path) # rubocop:disable Metrics/MethodLength
          progress_callback = nil

          if @options[:load_progress_callback]
            progress_callback = create_progress_callback
          end

          # Load database using existing QEA infrastructure
          if progress_callback
            Lutaml::Qea.load_database(file_path, &progress_callback)
          else
            Lutaml::Qea.load_database(file_path)
          end
        rescue StandardError => e
          add_error("Failed to load QEA database: #{e.message}")
          raise Parsers::ParseError.new("QEA database loading failed",
                                        original_error: e)
        end

        # Create progress callback for database loading
        #
        # @return [Proc] Progress callback procedure
        def create_progress_callback
          proc do |table_name, current, total|
            percentage = (current.to_f / total * 100).round(1)
            add_info("Loading #{table_name}: #{current}/#{total} " \
                     "(#{percentage}%)")

            # Check if we should fail fast on too many errors
            if should_fail_fast? && has_errors?
              raise Parsers::ParseError.new("Failing fast due to errors " \
                                            "during loading")
            end
          end
        end

        # Transform QEA database to UML document
        #
        # @param database [Lutaml::Qea::Database] QEA database
        # @param file_path [String] Source file path
        # @return [Lutaml::Uml::Document] UML document
        def transform_qea_to_uml(database, file_path) # rubocop:disable Metrics/MethodLength
          # Prepare transformation options
          transform_options = prepare_transformation_options(file_path)

          # Use existing QEA factory for transformation
          factory = Lutaml::Qea::Factory::EaToUmlFactory.new(database,
                                                             transform_options)

          # Apply custom transformers if configured
          apply_custom_transformers(factory) if @options[:custom_transformers]

          # Execute transformation
          factory.create_document
        rescue StandardError => e
          add_error("Failed to transform QEA to UML: #{e.message}")
          raise Parsers::ParseError.new("QEA transformation failed",
                                        original_error: e)
        end

        # Prepare transformation options from parser configuration
        #
        # @param file_path [String] Source file path
        # @return [Hash] Transformation options
        def prepare_transformation_options(file_path)
          {
            include_diagrams: @options[:include_diagrams],
            validate: @options[:validate_output],
            document_name: extract_document_name(file_path),
          }
        end

        # Extract document name from file path
        #
        # @param file_path [String] File path
        # @return [String] Document name
        def extract_document_name(file_path)
          @options[:document_name] || File.basename(file_path, ".*")
        end

        # Apply custom transformers to factory
        #
        # @param factory [Lutaml::Qea::Factory::EaToUmlFactory]
        # Factory to enhance
        # @return [void]
        def apply_custom_transformers(_factory)
          # This is a placeholder for future custom transformer support
          # Could allow configuration-driven transformer customization
          add_info("Custom transformers would be applied here")
        end

        # Post-process QEA document
        #
        # @param document [Lutaml::Uml::Document] Document to process
        # @param file_path [String] Source file path
        # @return [void]
        def post_process_qea_document(document, file_path)
          # Set QEA-specific source information
          if document.respond_to?(:source_file=)
            document.source_file = file_path
          end

          if document.respond_to?(:source_format=)
            document.source_format = "QEA"
          end

          # Store database statistics
          if document.respond_to?(:database_stats=)
            document.database_stats = @database_stats
          end
        end

        # Add QEA-specific metadata to document
        #
        # @param document [Lutaml::Uml::Document] Document to enhance
        # @param file_path [String] Source file path
        # @return [void]
        def add_qea_metadata(document, file_path) # rubocop:disable Metrics/MethodLength
          metadata = {
            source_file: file_path,
            source_format: "Enterprise Architect Database",
            parsed_at: Time.now,
            parser: self.class.name,
            parser_version: "1.0",
            database_stats: @database_stats,
            qea_version: detect_qea_version,
            options: @options,
          }

          # Store metadata using various approaches
          if document.respond_to?(:parsing_metadata=)
            document.parsing_metadata = metadata
          elsif document.respond_to?(:metadata=)
            document.metadata = metadata
          else
            document.instance_variable_set(:@qea_metadata, metadata)
          end
        end

        # Detect QEA/EA version from database
        #
        # @return [String] Detected version or "unknown"
        def detect_qea_version
          return "unknown" unless @qea_database

          # This is a simplified version detection
          # In practice, you might check specific tables or metadata
          "EA Database"
        end

        # Validate QEA transformation quality
        #
        # @param document [Lutaml::Uml::Document] Document to validate
        # @return [void]
        def validate_qea_transformation(document) # rubocop:disable Metrics/CyclomaticComplexity,Metrics/MethodLength,Metrics/PerceivedComplexity
          # Compare document stats with database stats
          if @database_stats
            doc_packages = document.packages&.size || 0
            db_packages = @database_stats["packages"] || 0

            if doc_packages < db_packages
              add_warning("Document has fewer packages (#{doc_packages}) " \
                          "than database (#{db_packages})")
            end

            doc_classes = document.classes&.size || 0
            db_objects = @database_stats["objects"] || 0

            if doc_classes < db_objects * 0.8 # Allow some variance
              add_warning("Document classes (#{doc_classes}) significantly " \
                          "fewer than database objects (#{db_objects})")
            end
          end
        end

        # Add comprehensive transformation statistics
        #
        # @param document [Lutaml::Uml::Document] Document to analyze
        # @return [void]
        def add_transformation_statistics(document) # rubocop:disable Metrics/AbcSize,Metrics/CyclomaticComplexity,Metrics/MethodLength,Metrics/PerceivedComplexity
          doc_stats = {
            packages: document.packages&.size || 0,
            classes: document.classes&.size || 0,
            data_types: document.data_types&.size || 0,
            enumerations: document.enums&.size || 0,
            associations: document.associations&.size || 0,
            diagrams: document.diagrams&.size || 0,
          }

          comparison = compare_stats_with_database(doc_stats)

          add_info("QEA transformation completed: " \
                   "#{format_statistics(doc_stats)}")
          if comparison.any?
            add_info("Database comparison: #{comparison.join(', ')}")
          end
        end

        # Compare document statistics with database statistics
        #
        # @param doc_stats [Hash] Document statistics
        # @return [Array<String>] Comparison notes
        def compare_stats_with_database(doc_stats) # rubocop:disable Metrics/AbcSize,Metrics/MethodLength
          return [] unless @database_stats

          comparisons = []

          if @database_stats["packages"]
            ratio = doc_stats[:packages].to_f / @database_stats["packages"]
            comparisons << "packages #{(ratio * 100).round(1)}%"
          end

          if @database_stats["objects"]
            ratio = doc_stats[:classes].to_f / @database_stats["objects"]
            comparisons << "classes #{(ratio * 100).round(1)}%"
          end

          comparisons
        end

        # Get quick database statistics without full loading
        #
        # @param file_path [String] Path to QEA file
        # @return [Hash] Quick statistics
        def get_quick_database_stats(file_path)
          Lutaml::Qea.database_info(file_path)
        end

        # Format database statistics for display
        #
        # @param stats [Hash] Statistics hash
        # @return [String] Formatted string
        def format_database_stats(stats)
          return "unknown structure" if stats.empty?

          parts = []
          parts << "#{stats['objects']} objects" if stats["objects"]
          parts << "#{stats['packages']} packages" if stats["packages"]
          parts << "#{stats['connectors']} connectors" if stats["connectors"]

          parts.join(", ")
        end

        # Format file size for display
        #
        # @param size [Integer] Size in bytes
        # @return [String] Formatted size string
        def format_file_size(size)
          units = %w[B KB MB GB]
          size = size.to_f
          unit_index = 0

          while size >= 1024 && unit_index < units.length - 1
            size /= 1024
            unit_index += 1
          end

          "#{size.round(1)} #{units[unit_index]}"
        end

        # Format statistics for display
        #
        # @param stats [Hash] Statistics hash
        # @return [String] Formatted statistics string
        def format_statistics(stats)
          parts = stats.map { |key, value| "#{value} #{key}" }
          parts.join(", ")
        end

        # Add info message (similar to warning but for information)
        #
        # @param message [String] Info message
        # @param context [Hash] Additional context
        # @return [void]
        def add_info(message, context = {})
          # For now, treat as warnings since base parser doesn't have info level
          add_warning(message, context)
        end
      end
    end
  end
end
