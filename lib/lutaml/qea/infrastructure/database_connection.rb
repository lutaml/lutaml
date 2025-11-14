# frozen_string_literal: true

require "sqlite3"

module Lutaml
  module Qea
    module Infrastructure
      # DatabaseConnection manages the SQLite database connection lifecycle
      # for QEA files (Enterprise Architect SQLite databases).
      #
      # @example Connect to a QEA file
      #   conn = DatabaseConnection.new("model.qea")
      #   conn.connect
      #   # ... use connection
      #   conn.close
      #
      # @example Using with_connection block
      #   conn = DatabaseConnection.new("model.qea")
      #   conn.with_connection do |db|
      #     # ... use db
      #   end
      class DatabaseConnection
        attr_reader :file_path, :connection

        # Initialize a new database connection
        #
        # @param file_path [String] Path to the .qea file
        # @raise [ArgumentError] if file_path is nil or empty
        def initialize(file_path)
          if file_path.nil? || file_path.empty?
            raise ArgumentError,
                  "file_path cannot be nil or empty"
          end

          @file_path = file_path
          @connection = nil
        end

        # Connect to the database
        #
        # @return [SQLite3::Database] The database connection
        # @raise [Errno::ENOENT] if the file does not exist
        # @raise [SQLite3::Exception] if connection fails
        def connect
          unless File.exist?(@file_path)
            raise Errno::ENOENT, "QEA file not found: #{@file_path}"
          end

          @connection = SQLite3::Database.new(@file_path, readonly: true)
          @connection.results_as_hash = true
          @connection
        end

        # Close the database connection
        #
        # @return [void]
        def close
          return unless @connection

          @connection.close
          @connection = nil
        end

        # Check if the connection is open
        #
        # @return [Boolean] true if connection is open
        def connected?
          !@connection.nil? && !@connection.closed?
        end

        # Execute a block with an active connection
        #
        # This method ensures the connection is properly opened and closed.
        # If a connection already exists, it reuses it. Otherwise, it creates
        # a new connection and closes it after the block executes.
        #
        # @yield [SQLite3::Database] The database connection
        # @return [Object] The result of the block
        # @raise [Errno::ENOENT] if the file does not exist
        # @raise [SQLite3::Exception] if connection fails
        #
        # @example
        #   conn = DatabaseConnection.new("model.qea")
        #   result = conn.with_connection do |db|
        #     db.execute("SELECT COUNT(*) FROM t_object")
        #   end
        def with_connection
          should_close = !connected?

          begin
            connect unless connected?
            yield @connection
          ensure
            close if should_close
          end
        end
      end
    end
  end
end
