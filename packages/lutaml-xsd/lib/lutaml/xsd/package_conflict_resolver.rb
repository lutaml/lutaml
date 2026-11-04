# frozen_string_literal: true

module Lutaml
  module Xsd
    # Service class for resolving conflicts
    class PackageConflictResolver
      attr_reader :conflict_report, :package_sources

      def initialize(conflict_report, package_sources)
        @conflict_report = conflict_report
        @package_sources = package_sources.sort_by(&:priority)
      end

      # Resolve conflicts and determine load order
      # @return [Array<PackageSource>] Ordered sources for loading
      # @raise [PackageMergeError] If unresolvable conflicts
      def resolve
        error_strategy_sources = @package_sources.select do |s|
          s.conflict_resolution == "error"
        end

        if error_strategy_sources.any? && @conflict_report.has_conflicts?
          raise PackageMergeError.new(
            message: "Conflicts detected with 'error' resolution strategy",
            conflict_report: @conflict_report,
            error_strategy_sources: error_strategy_sources,
          )
        end

        @package_sources
      end

      # Determine winner for a specific conflict
      def resolve_conflict(conflict)
        sources = case conflict
                  when Conflicts::NamespaceConflict, Conflicts::TypeConflict
                    conflict.sources
                  when Conflicts::SchemaConflict
                    conflict.source_files.filter_map do |fs|
                      @package_sources.find do |ps|
                        ps.package_path == fs.package_path
                      end
                    end
                  end

        resolve_by_priority(sources)
      end

      private

      def resolve_by_priority(sources)
        sorted = sources.sort_by(&:priority)
        winner = sorted.first

        case winner.conflict_resolution
        when "keep" then sorted.first
        when "override" then sorted.last
        when "error"
          raise PackageMergeError.new(
            message: "Conflict with 'error' strategy",
            conflict_report: @conflict_report,
            error_strategy_sources: [winner],
          )
        end
      end
    end
  end
end
