# frozen_string_literal: true

module Lutaml
  module Xsd
    # Executes batch type queries
    # Single responsibility: process multiple type lookups efficiently
    class BatchTypeQuery
      attr_reader :repository

      def initialize(repository)
        @repository = repository
      end

      # Execute batch query from array of qualified names
      # @param qualified_names [Array<String>] Array of qualified type names
      # @return [Array<BatchQueryResult>] Array of query results
      def execute(qualified_names)
        qualified_names.map do |qname|
          result = @repository.find_type(qname.strip)

          BatchQueryResult.new(
            query: qname,
            resolved: result.resolved?,
            result: result,
          )
        end
      end

      # Execute from file
      # @param file_path [String] Path to file containing qualified names
      # @return [Array<BatchQueryResult>] Array of query results
      def execute_from_file(file_path)
        names = File.readlines(file_path).map(&:strip).reject(&:empty?)
        execute(names)
      end

      # Execute from stdin
      # @return [Array<BatchQueryResult>] Array of query results
      def execute_from_stdin
        names = $stdin.readlines.map(&:strip).reject(&:empty?)
        execute(names)
      end
    end

    # Value object for batch query result
    # Encapsulates individual query result with metadata
    class BatchQueryResult
      attr_reader :query, :resolved, :result

      def initialize(query:, resolved:, result:)
        @query = query
        @resolved = resolved
        @result = result
      end

      # Convert to hash representation
      # @return [Hash] Hash representation of the result
      def to_h
        {
          query: query,
          resolved: resolved,
          qualified_name: result.qname,
          namespace: result.namespace,
          type_class: resolved ? result.definition.class.name : nil,
        }
      end
    end
  end
end
