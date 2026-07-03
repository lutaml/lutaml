# frozen_string_literal: true

module Lutaml
  module Qea
    module Infrastructure
      # TableReader reads data from a single table in a QEA SQLite database.
      #
      # This class provides methods to query and retrieve records from
      # database tables with filtering and counting capabilities.
      #
      # @example Read all records from a table
      #   reader = TableReader.new(db_connection, "t_object")
      #   objects = reader.all
      #
      # @example Read with filtering
      #   reader = TableReader.new(db_connection, "t_object")
      #   classes = reader.where("Object_Type = ?", "Class")
      class TableReader
        attr_reader :database, :table_name

        # Initialize a new table reader
        #
        # @param database [SQLite3::Database] The database connection
        # @param table_name [String] The table name to read from
        # @raise [ArgumentError] if database or table_name is nil
        def initialize(database, table_name)
          raise ArgumentError, "database cannot be nil" if database.nil?

          if table_name.nil? || table_name.empty?
            raise ArgumentError,
                  "table_name cannot be nil or empty"
          end

          @database = database
          @table_name = table_name
        end

        # Read all records from the table
        #
        # @param limit [Integer, nil] Maximum number of records to return
        # (optional)
        # @param offset [Integer, nil] Number of records to skip (optional)
        # @return [Array<Hash>] Array of record hashes
        #
        # @example
        #   reader.all
        #   # => [{"Object_ID"=>1, "Name"=>"MyClass", ...}, ...]
        #
        # @example With limit
        #   reader.all(limit: 10)
        #   # => Returns first 10 records
        def all(limit: nil, offset: nil) # rubocop:disable Metrics/MethodLength
          query = "SELECT * FROM #{@table_name}"
          params = []

          if limit
            query += " LIMIT ?"
            params << limit
          end

          if offset
            query += " OFFSET ?"
            params << offset
          end

          @database.execute(query, params)
        end

        # Read records matching a WHERE clause
        #
        # @param conditions [String] The WHERE clause
        # (without the WHERE keyword)
        # @param values [Array] Values for parameterized query placeholders
        # @param limit [Integer, nil] Maximum number of records
        # to return (optional)
        # @param offset [Integer, nil] Number of records to skip (optional)
        # @return [Array<Hash>] Array of matching record hashes
        #
        # @example Simple filter
        #   reader.where("Object_Type = ?", "Class")
        #
        # @example Multiple conditions
        #   reader.where("Object_Type = ? AND Package_ID = ?", "Class", 5)
        #
        # @example With limit
        #   reader.where("Object_Type = ?", "Class", limit: 10)
        def where(conditions, *values, limit: nil, offset: nil) # rubocop:disable Metrics/MethodLength
          query = "SELECT * FROM #{@table_name} WHERE #{conditions}"
          params = values.flatten

          if limit
            query += " LIMIT ?"
            params << limit
          end

          if offset
            query += " OFFSET ?"
            params << offset
          end

          @database.execute(query, params)
        end

        # Count all records in the table
        #
        # @return [Integer] Total number of records
        def count
          result = @database.execute(
            "SELECT COUNT(*) as count FROM #{@table_name}",
          )
          result.first["count"]
        end

        # Count records matching a WHERE clause
        #
        # @param conditions [String] The WHERE clause
        # (without the WHERE keyword)
        # @param values [Array] Values for parameterized query placeholders
        # @return [Integer] Number of matching records
        #
        # @example
        #   reader.count_where("Object_Type = ?", "Class")
        #   # => 42
        def count_where(conditions, *values)
          query = "SELECT COUNT(*) as count FROM #{@table_name} " \
                  "WHERE #{conditions}"
          result = @database.execute(query, values.flatten)
          result.first["count"]
        end

        # Find a single record by primary key value
        #
        # @param primary_key_column [String] The primary key column name
        # @param value [Object] The primary key value to search for
        # @return [Hash, nil] The matching record hash, or nil if not found
        #
        # @example
        #   reader.find_by_pk("Object_ID", 123)
        #   # => {"Object_ID"=>123, "Name"=>"MyClass", ...}
        def find_by_pk(primary_key_column, value)
          query = "SELECT * FROM #{@table_name} " \
                  "WHERE #{primary_key_column} = ? LIMIT 1"
          result = @database.execute(query, [value])
          result.first
        end

        # Find first record matching a WHERE clause
        #
        # @param conditions [String] The WHERE clause
        # (without the WHERE keyword)
        # @param values [Array] Values for parameterized query placeholders
        # @return [Hash, nil] The first matching record hash,
        # or nil if not found
        #
        # @example
        #   reader.find_first("Name = ?", "MyClass")
        #   # => {"Object_ID"=>123, "Name"=>"MyClass", ...}
        def find_first(conditions, *values)
          query = "SELECT * FROM #{@table_name} WHERE #{conditions} LIMIT 1"
          result = @database.execute(query, values.flatten)
          result.first
        end

        # Execute a custom SQL query on this table
        #
        # @param sql [String] The SQL query (should reference the table)
        # @param params [Array] Parameters for the query
        # @return [Array<Hash>] Query results
        #
        # @example
        #   reader.execute_query(
        #     "SELECT Name, COUNT(*) as count FROM #{reader.table_name}
        #      GROUP BY Name"
        #   )
        def execute_query(sql, params = [])
          @database.execute(sql, params)
        end

        # Check if any records match the given conditions
        #
        # @param conditions [String] The WHERE clause
        # (without the WHERE keyword)
        # @param values [Array] Values for parameterized query placeholders
        # @return [Boolean] true if at least one record matches
        #
        # @example
        #   reader.exists?("Name = ?", "MyClass")
        #   # => true or false
        def exists?(conditions, *values)
          count_where(conditions, *values).positive?
        end

        # Read records with custom column selection
        #
        # @param columns [Array<String>] Column names to select
        # @param conditions [String, nil] Optional WHERE clause
        # @param values [Array] Values for parameterized query placeholders
        # @param limit [Integer, nil] Maximum number of records to return
        # @return [Array<Hash>] Array of record hashes with selected columns
        #
        # @example
        #   reader.select(["Object_ID", "Name"], "Object_Type = ?", "Class")
        #   # => [{"Object_ID"=>1, "Name"=>"Class1"}, ...]
        def select(columns, conditions = nil, *values, limit: nil) # rubocop:disable Metrics/MethodLength
          column_list = columns.join(", ")
          query = "SELECT #{column_list} FROM #{@table_name}"

          params = []
          if conditions
            query += " WHERE #{conditions}"
            params = values.flatten
          end

          if limit
            query += " LIMIT ?"
            params << limit
          end

          @database.execute(query, params)
        end
      end
    end
  end
end
