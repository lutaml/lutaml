# frozen_string_literal: true

require "sqlite3"

module Lutaml
  module Qea
    # Utility for detecting and validating QEA files
    class FileDetector
      # SQLite magic bytes
      SQLITE_MAGIC = "SQLite format 3\x00"

      # Required EA tables for valid QEA file
      REQUIRED_EA_TABLES = %w[
        t_object
        t_attribute
        t_connector
        t_package
      ].freeze

      class << self
        # Check if file is a QEA file
        #
        # @param path [String] File path
        # @return [Boolean] True if file appears to be QEA
        def qea_file?(path)
          return false unless File.exist?(path)
          return false unless File.file?(path)
          return false unless path.end_with?(".qea")

          # Quick check: is it SQLite?
          sqlite_file?(path)
        end

        # Validate QEA file structure
        #
        # @param path [String] File path
        # @return [Hash] Validation result with :valid, :errors, :warnings
        #
        # @example
        #   result = FileDetector.validate_qea("model.qea")
        #   if result[:valid]
        #     puts "Valid QEA file"
        #   else
        #     puts "Errors: #{result[:errors]}"
        #   end
        def validate_qea(path)
          errors = []
          warnings = []

          # Check file exists
          unless File.exist?(path)
            return {
              valid: false,
              errors: ["File not found: #{path}"],
              warnings: [],
            }
          end

          # Check file extension
          unless path.end_with?(".qea")
            warnings << "File does not have .qea extension"
          end

          # Check SQLite format
          unless sqlite_file?(path)
            errors << "File is not a valid SQLite database"
            return { valid: false, errors: errors, warnings: warnings }
          end

          # Check for EA tables
          begin
            db = SQLite3::Database.new(path, readonly: true)
            tables = get_table_names(db)

            REQUIRED_EA_TABLES.each do |required_table|
              unless tables.include?(required_table)
                errors << "Missing required EA table: #{required_table}"
              end
            end

            # Check for data
            if tables.include?("t_object")
              count = db.execute("SELECT COUNT(*) FROM t_object").first.first
              if count.zero?
                warnings << "No objects found in t_object table"
              end
            end
          rescue SQLite3::Exception => e
            errors << "Failed to open database: #{e.message}"
          ensure
            db&.close
          end

          {
            valid: errors.empty?,
            errors: errors,
            warnings: warnings,
          }
        end

        # Get file information
        #
        # @param path [String] File path
        # @return [Hash] File information
        #
        # @example
        #   info = FileDetector.file_info("model.qea")
        #   puts "Size: #{info[:size_mb]} MB"
        #   puts "Tables: #{info[:table_count]}"
        def file_info(path)
          return { error: "File not found" } unless File.exist?(path)

          info = {
            path: path,
            size_bytes: File.size(path),
            size_mb: (File.size(path) / 1024.0 / 1024.0).round(2),
            modified: File.mtime(path),
            is_qea: qea_file?(path),
          }

          if sqlite_file?(path)
            begin
              db = SQLite3::Database.new(path, readonly: true)
              tables = get_table_names(db)
              info[:is_sqlite] = true
              info[:table_count] = tables.size
              info[:has_ea_tables] = REQUIRED_EA_TABLES.all? do |t|
                tables.include?(t)
              end

              # Get record counts for key tables
              if tables.include?("t_object")
                info[:object_count] =
                  db.execute("SELECT COUNT(*) FROM t_object").first.first
              end
              if tables.include?("t_package")
                info[:package_count] =
                  db.execute("SELECT COUNT(*) FROM t_package").first.first
              end
            rescue SQLite3::Exception => e
              info[:error] = e.message
            ensure
              db&.close
            end
          else
            info[:is_sqlite] = false
          end

          info
        end

        private

        # Check if file is SQLite database
        #
        # @param path [String] File path
        # @return [Boolean] True if SQLite database
        def sqlite_file?(path)
          File.open(path, "rb") do |f|
            magic = f.read(16)
            magic == SQLITE_MAGIC
          end
        rescue StandardError
          false
        end

        # Get table names from database
        #
        # @param db [SQLite3::Database] Database connection
        # @return [Array<String>] Table names
        def get_table_names(db)
          db.execute("SELECT name FROM sqlite_master WHERE type='table'")
            .flatten
        end
      end
    end
  end
end
