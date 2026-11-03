# frozen_string_literal: true

module Lutaml
  module Xsd
    module Conflicts
      # Namespace URI conflict between packages
      # Serializable for reporting
      class NamespaceConflict < Lutaml::Model::Serializable
        attribute :namespace_uri, :string
        attribute :package_paths, :string, collection: true
        attribute :priorities, :integer, collection: true

        yaml do
          map "namespace_uri", to: :namespace_uri
          map "package_paths", to: :package_paths
          map "priorities", to: :priorities
        end

        # Runtime-only (not serialized)
        attr_accessor :sources

        # Create from PackageSource objects
        # @param namespace_uri [String] The namespace URI
        # @param sources [Array<PackageSource>] Conflicting package sources
        # @return [NamespaceConflict]
        def self.from_sources(namespace_uri:, sources:)
          conflict = new(
            namespace_uri: namespace_uri,
            package_paths: sources.map(&:package_path),
            priorities: sources.map(&:priority),
          )
          conflict.sources = sources
          conflict
        end

        def conflict_count
          package_paths.size
        end

        def highest_priority_source
          sources&.min_by(&:priority)
        end

        def to_s
          "Namespace '{#{namespace_uri}}' defined in #{conflict_count} packages"
        end

        def detailed_description
          lines = []
          lines << "Namespace URI Conflict:"
          lines << "  Namespace: {#{namespace_uri}}"
          lines << "  Defined in packages:"
          package_paths.each_with_index do |path, idx|
            lines << "    - #{path} (priority: #{priorities[idx]})"
          end
          lines.join("\n")
        end
      end
    end
  end
end
