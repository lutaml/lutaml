# frozen_string_literal: true

module Lutaml
  module Xsd
    # Package information for serialization
    class PackageInfo < Lutaml::Model::Serializable
      attribute :package_path, :string
      attribute :priority, :integer
      attribute :conflict_resolution, :string

      yaml do
        map "package_path", to: :package_path
        map "priority", to: :priority
        map "conflict_resolution", to: :conflict_resolution
      end

      def self.from_source(package_source)
        new(
          package_path: package_source.package_path,
          priority: package_source.priority,
          conflict_resolution: package_source.conflict_resolution,
        )
      end
    end

    # Comprehensive conflict report with serialization
    # to_hash, to_json, to_yaml provided by Lutaml::Model
    class ConflictReport < Lutaml::Model::Serializable
      attribute :namespace_conflicts, Conflicts::NamespaceConflict,
                collection: true
      attribute :type_conflicts, Conflicts::TypeConflict, collection: true
      attribute :schema_conflicts, Conflicts::SchemaConflict, collection: true
      attribute :package_info, PackageInfo, collection: true

      yaml do
        map "namespace_conflicts", to: :namespace_conflicts
        map "type_conflicts", to: :type_conflicts
        map "schema_conflicts", to: :schema_conflicts
        map "package_info", to: :package_info
      end

      # Runtime-only reference to PackageSource objects
      attr_accessor :package_sources

      # Create from detection results
      # @param namespace_conflicts [Array<Conflicts::NamespaceConflict>]
      # @param type_conflicts [Array<Conflicts::TypeConflict>]
      # @param schema_conflicts [Array<Conflicts::SchemaConflict>]
      # @param package_sources [Array<PackageSource>]
      # @return [ConflictReport]
      def self.from_conflicts(namespace_conflicts:, type_conflicts:,
schema_conflicts:, package_sources:)
        report = new(
          namespace_conflicts: namespace_conflicts,
          type_conflicts: type_conflicts,
          schema_conflicts: schema_conflicts,
          package_info: package_sources.map do |ps|
            PackageInfo.from_source(ps)
          end,
        )
        report.package_sources = package_sources
        report
      end

      def has_conflicts?
        total_conflicts.positive?
      end

      def total_conflicts
        namespace_conflicts.size + type_conflicts.size + schema_conflicts.size
      end

      def all_conflicts
        namespace_conflicts + type_conflicts + schema_conflicts
      end

      # Human-readable text format
      # @return [String]
      def to_s
        return "✓ No conflicts detected" unless has_conflicts?

        lines = []
        lines << "❌ Package Merge Conflicts Detected"
        lines << ("=" * 80)
        lines << ""
        lines << "Total conflicts: #{total_conflicts}"
        lines << "  - Namespace conflicts: #{namespace_conflicts.size}"
        lines << "  - Type conflicts: #{type_conflicts.size}"
        lines << "  - Schema conflicts: #{schema_conflicts.size}"
        lines << ""

        if namespace_conflicts.any?
          lines << "Namespace URI Conflicts:"
          lines << ("-" * 80)
          namespace_conflicts.each_with_index do |conflict, idx|
            lines << "#{idx + 1}. #{conflict.detailed_description}"
            lines << ""
          end
        end

        if type_conflicts.any?
          lines << "Type Name Conflicts:"
          lines << ("-" * 80)
          type_conflicts.each_with_index do |conflict, idx|
            lines << "#{idx + 1}. #{conflict.detailed_description}"
            lines << ""
          end
        end

        if schema_conflicts.any?
          lines << "Schema File Conflicts:"
          lines << ("-" * 80)
          schema_conflicts.each_with_index do |conflict, idx|
            lines << "#{idx + 1}. #{conflict.detailed_description}"
            lines << ""
          end
        end

        lines << format_resolution_strategies
        lines << ""
        lines << format_resolution_guidance

        lines.join("\n")
      end

      private

      def format_resolution_strategies
        lines = []
        lines << "Resolution Strategies:"
        lines << ("-" * 80)
        package_info.sort_by(&:priority).each do |info|
          lines << "Package: #{info.package_path}"
          lines << "  Priority: #{info.priority}"
          lines << "  Strategy: #{info.conflict_resolution}"
          lines << ""
        end
        lines.join("\n")
      end

      def format_resolution_guidance
        [
          "💡 To resolve conflicts:",
          "   1. Update package priorities (lower = higher priority)",
          "   2. Set conflict_resolution to 'keep' or 'override'",
          "   3. Use namespace_remapping to avoid URI conflicts",
          "   4. Use exclude_schemas to filter problematic schemas",
        ].join("\n")
      end
    end
  end
end
