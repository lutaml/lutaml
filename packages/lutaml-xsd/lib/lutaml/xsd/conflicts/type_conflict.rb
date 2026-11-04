# frozen_string_literal: true

module Lutaml
  module Xsd
    module Conflicts
      # Type name conflict within a namespace
      class TypeConflict < Lutaml::Model::Serializable
        attribute :namespace_uri, :string
        attribute :type_name, :string
        attribute :package_paths, :string, collection: true
        attribute :priorities, :integer, collection: true

        yaml do
          map "namespace_uri", to: :namespace_uri
          map "type_name", to: :type_name
          map "package_paths", to: :package_paths
          map "priorities", to: :priorities
        end

        # Runtime-only
        attr_accessor :sources

        def self.from_sources(namespace_uri:, type_name:, sources:)
          conflict = new(
            namespace_uri: namespace_uri,
            type_name: type_name,
            package_paths: sources.map(&:package_path),
            priorities: sources.map(&:priority),
          )
          conflict.sources = sources
          conflict
        end

        def qualified_name
          "{#{namespace_uri}}#{type_name}"
        end

        def conflict_count
          package_paths.size
        end

        def highest_priority_source
          sources&.min_by(&:priority)
        end

        def to_s
          "Type '#{type_name}' in '{#{namespace_uri}}' defined in #{conflict_count} packages"
        end

        def detailed_description
          lines = []
          lines << "Type Name Conflict:"
          lines << "  Type: #{qualified_name}"
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
