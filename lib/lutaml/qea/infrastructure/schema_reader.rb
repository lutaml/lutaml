# frozen_string_literal: true

module Lutaml
  module Qea
    module Infrastructure
      # SchemaReader reads database schema information from a
      # QEA SQLite database.
      #
      # This class is responsible for introspecting the database schema,
      # including table names, column definitions, and metadata.
      #
      # @example Read schema information
      #   reader = SchemaReader.new(db_connection)
      #   tables = reader.tables
      #   columns = reader.columns("t_object")
      class SchemaReader
        attr_reader :database

        # Initialize a new schema reader
        #
        # @param database [SQLite3::Database] The database connection
        # @raise [ArgumentError] if database is nil
        def initialize(database)
          raise ArgumentError, "database cannot be nil" if database.nil?

          @database = database
        end

        # Get list of all table names in the database
        #
        # @param exclude_system [Boolean]
        # Exclude SQLite system tables (default: true)
        # @return [Array<String>] List of table names
        def tables(exclude_system: true)
          query = "SELECT name FROM sqlite_master WHERE type='table'"
          query += " AND name NOT LIKE 'sqlite_%'" if exclude_system
          query += " ORDER BY name"

          @database.execute(query).map { |row| row["name"] }
        end

        # Get column information for a specific table
        #
        # @param table_name [String] The table name
        # @return [Array<Hash>] Array of column information hashes
        #   Each hash contains: name, type, notnull, dflt_value, pk
        #
        # @example
        #   columns = reader.columns("t_object")
        #   # => [
        #   #   {"cid"=>0, "name"=>"Object_ID", "type"=>"INTEGER",
        #   #    "notnull"=>1, "dflt_value"=>nil, "pk"=>1},
        #   #   ...
        #   # ]
        def columns(table_name)
          @database.execute("PRAGMA table_info(#{table_name})")
        end

        # Get just column names for a specific table
        #
        # @param table_name [String] The table name
        # @return [Array<String>] List of column names
        def column_names(table_name)
          columns(table_name).map { |col| col["name"] }
        end

        # Check if a table exists in the database
        #
        # @param table_name [String] The table name to check
        # @return [Boolean] true if table exists
        def table_exists?(table_name)
          result = @database.execute(
            "SELECT name FROM sqlite_master WHERE type='table' AND name=?",
            table_name,
          )
          !result.empty?
        end

        # Get primary key column name for a table
        #
        # @param table_name [String] The table name
        # @return [String, nil] The primary key column name,
        # or nil if no primary key
        def primary_key(table_name)
          pk_column = columns(table_name).find { |col| col["pk"] == 1 }
          pk_column&.fetch("name", nil)
        end

        # Get table schema as CREATE TABLE statement
        #
        # @param table_name [String] The table name
        # @return [String, nil] The CREATE TABLE SQL statement,
        # or nil if table doesn't exist
        def table_schema(table_name)
          result = @database.execute(
            "SELECT sql FROM sqlite_master WHERE type='table' AND name=?",
            table_name,
          )
          result.first&.fetch("sql", nil)
        end

        # Get index information for a table
        #
        # @param table_name [String] The table name
        # @return [Array<Hash>] Array of index information
        def indexes(table_name)
          @database.execute(
            "SELECT name, sql FROM sqlite_master " \
            "WHERE type='index' AND tbl_name=?",
            table_name,
          )
        end

        # Get row count for a table
        #
        # @param table_name [String] The table name
        # @return [Integer] Number of rows in the table
        def row_count(table_name)
          result = @database.execute(
            "SELECT COUNT(*) as count FROM #{table_name}",
          )
          result.first["count"]
        end

        # Get schema statistics for all tables
        #
        # @return [Hash] Hash mapping table names to row counts
        def statistics
          tables.each_with_object({}) do |table_name, stats|
            stats[table_name] = row_count(table_name)
          end
        end
      end
    end
  end
end
