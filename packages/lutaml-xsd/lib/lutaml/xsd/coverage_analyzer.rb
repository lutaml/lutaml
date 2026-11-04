# frozen_string_literal: true

require_relative "dependency_grapher"

module Lutaml
  module Xsd
    # Analyzes schema coverage based on entry point types
    # Single responsibility: trace type usage from entry points
    class CoverageAnalyzer
      attr_reader :repository

      def initialize(repository)
        @repository = repository
        @type_index = repository.instance_variable_get(:@type_index)
        @dependency_grapher = DependencyGrapher.new(repository)
      end

      # Analyze coverage starting from entry types
      # @param entry_types [Array<String>] Entry point type names
      # @return [CoverageReport]
      def analyze(entry_types: [])
        # Collect all types across all namespaces
        all_types = collect_all_types

        # Trace all types reachable from entry points
        used_types = trace_dependencies_from_entries(entry_types)

        # Calculate coverage per namespace
        by_namespace = analyze_by_namespace(all_types, used_types)

        CoverageReport.new(
          all_types: all_types,
          used_types: used_types,
          entry_types: entry_types,
          by_namespace: by_namespace,
        )
      end

      private

      # Collect all types across all namespaces
      # @return [Set<String>] Set of all type Clark keys
      def collect_all_types
        all_types = Set.new

        @type_index.all.each_key do |clark_key|
          all_types.add(clark_key)
        end

        all_types
      end

      # Recursively trace all types reachable from entries
      # Uses DependencyGrapher for consistency
      # @param entry_types [Array<String>] Entry point type names
      # @return [Set<String>] Set of used type Clark keys
      def trace_dependencies_from_entries(entry_types)
        used_types = Set.new
        visited = Set.new

        entry_types.each do |entry_qname|
          trace_type_dependencies(entry_qname, used_types, visited)
        end

        used_types
      end

      # Trace dependencies for a single type
      # @param qname [String] Qualified name of the type
      # @param used_types [Set] Accumulator for used types
      # @param visited [Set] Visited types to avoid cycles
      def trace_type_dependencies(qname, used_types, visited)
        # Resolve the type to get its Clark key
        result = @repository.find_type(qname)
        return unless result.resolved?

        clark_key = build_clark_key(result.namespace, result.local_name)

        # Skip if already visited
        return if visited.include?(clark_key)

        visited.add(clark_key)
        used_types.add(clark_key)

        # Get all type references from this definition
        refs = @dependency_grapher.extract_type_references(result.definition)

        # Recursively trace each reference
        refs.each do |ref|
          trace_type_dependencies(ref, used_types, visited)
        end
      end

      # Calculate coverage per namespace
      # @param all_types [Set<String>] All types
      # @param used_types [Set<String>] Used types
      # @return [Hash] Coverage data by namespace
      def analyze_by_namespace(_all_types, used_types)
        by_ns = {}

        @type_index.all.each do |clark_key, type_info|
          ns = type_info[:namespace] || "(no namespace)"

          by_ns[ns] ||= {
            total: 0,
            used: 0,
            types: [],
          }

          by_ns[ns][:total] += 1
          by_ns[ns][:types] << {
            clark_key: clark_key,
            name: type_info[:definition]&.name,
            category: type_info[:type],
            used: used_types.include?(clark_key),
          }

          by_ns[ns][:used] += 1 if used_types.include?(clark_key)
        end

        # Calculate percentages
        by_ns.each_value do |data|
          data[:coverage_percentage] = if data[:total].zero?
                                         0.0
                                       else
                                         (data[:used].to_f / data[:total] * 100).round(2)
                                       end
        end

        by_ns
      end

      # Build Clark notation key
      # @param namespace [String, nil] Namespace URI
      # @param local_name [String] Local name
      # @return [String] Clark notation key
      def build_clark_key(namespace, local_name)
        if namespace && !namespace.empty?
          "{#{namespace}}#{local_name}"
        else
          local_name
        end
      end
    end

    # Value object representing coverage analysis results
    # Immutable data structure with computed properties
    class CoverageReport
      attr_reader :all_types, :used_types, :entry_types, :by_namespace

      def initialize(all_types:, used_types:, entry_types:, by_namespace:)
        @all_types = all_types
        @used_types = used_types
        @entry_types = entry_types
        @by_namespace = by_namespace
      end

      # Total number of types in the repository
      # @return [Integer]
      def total_types
        all_types.size
      end

      # Number of used types
      # @return [Integer]
      def used_count
        used_types.size
      end

      # Get unused types (MECE: mutually exclusive with used_types)
      # @return [Set<String>]
      def unused_types
        all_types - used_types
      end

      # Number of unused types
      # @return [Integer]
      def unused_count
        unused_types.size
      end

      # Overall coverage percentage
      # @return [Float]
      def coverage_percentage
        return 0.0 if total_types.zero?

        (used_count.to_f / total_types * 100).round(2)
      end

      # Convert to hash for serialization
      # @return [Hash]
      def to_h
        {
          summary: {
            total_types: total_types,
            used_types: used_count,
            unused_types: unused_count,
            coverage_percentage: coverage_percentage,
            entry_types: entry_types,
          },
          by_namespace: format_namespace_data,
          unused_type_details: format_unused_types,
        }
      end

      private

      # Format namespace data for serialization
      # @return [Hash]
      def format_namespace_data
        result = {}

        by_namespace.each do |ns, data|
          result[ns] = {
            total: data[:total],
            used: data[:used],
            unused: data[:total] - data[:used],
            coverage_percentage: data[:coverage_percentage],
          }
        end

        result
      end

      # Format unused types with details
      # @return [Array<Hash>]
      def format_unused_types
        unused_details = []

        by_namespace.each do |ns, data|
          data[:types].each do |type_info|
            next if type_info[:used]

            unused_details << {
              namespace: ns,
              name: type_info[:name],
              category: type_info[:category],
              clark_key: type_info[:clark_key],
            }
          end
        end

        unused_details.sort_by { |t| [t[:namespace], t[:name]] }
      end
    end
  end
end
