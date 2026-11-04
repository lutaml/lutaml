# frozen_string_literal: true

module Lutaml
  module Xsd
    module Conflicts
      # Schema file source
      class SchemaFileSource < Lutaml::Model::Serializable
        attribute :package_path, :string
        attribute :schema_file, :string
        attribute :priority, :integer

        yaml do
          map "package_path", to: :package_path
          map "schema_file", to: :schema_file
          map "priority", to: :priority
        end
      end

      # Schema file conflict
      class SchemaConflict < Lutaml::Model::Serializable
        attribute :schema_basename, :string
        attribute :source_files, SchemaFileSource, collection: true

        yaml do
          map "schema_basename", to: :schema_basename
          map "source_files", to: :source_files
        end

        def conflict_count
          source_files.size
        end

        def package_paths
          source_files.map(&:package_path)
        end

        def file_paths
          source_files.map(&:schema_file)
        end

        def highest_priority_source
          source_files.min_by(&:priority)
        end

        def to_s
          "Schema '#{schema_basename}' found in #{conflict_count} packages"
        end

        def detailed_description
          lines = []
          lines << "Schema File Conflict:"
          lines << "  Schema: #{schema_basename}"
          lines << "  Found in packages:"
          source_files.each do |source|
            lines << "    - #{source.package_path} (priority: #{source.priority})"
            lines << "      File: #{source.schema_file}"
          end
          lines.join("\n")
        end
      end
    end
  end
end
