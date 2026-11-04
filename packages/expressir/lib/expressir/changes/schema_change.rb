# frozen_string_literal: true

module Expressir
  module Changes
    # Represents changes to an EXPRESS schema across multiple versions
    class SchemaChange < Lutaml::Model::Serializable
      attribute :schema, :string
      attribute :versions, VersionChange, collection: true

      yaml do
        map "schema", to: :schema
        map "versions", to: :versions
      end

      class << self
        # Load a SchemaChange from a YAML file
        #
        # @param path [String] Path to the YAML file
        # @return [SchemaChange] The loaded schema changes
        def from_file(path)
          content = File.read(path)
          # Handle empty or minimal YAML files
          # Skip leading comments and empty lines
          lines = content.lines
          yaml_start_index = lines.find_index do |line|
            !line.strip.start_with?("#") && !line.strip.empty?
          end

          if yaml_start_index
            content = lines[yaml_start_index..].join
          end

          return new if content.strip == "---" || content.strip.empty?

          from_yaml(content)
        end
      end

      # Add or update a change version in this schema
      #
      # @param version [String] Version number
      # @param description [String] Description of changes
      # @param changes [Hash] Hash with :additions, :modifications, :deletions
      # @return [VersionChange] The added or updated version
      def add_or_update_version(version, description, changes)
        # Initialize versions array if nil
        self.versions ||= []

        # Find existing version with this version
        existing_index = versions.find_index do |ed|
          ed.version == version
        end

        # Create new version
        version = VersionChange.new(
          version: version,
          description: description,
          additions: changes[:additions] || [],
          modifications: changes[:modifications] || [],
          deletions: changes[:deletions] || [],
        )

        if existing_index
          # Replace existing version with same version
          versions[existing_index] = version
        else
          # Add new version
          versions << version
        end

        version
      end

      # Save this SchemaChange to a YAML file
      #
      # @param path [String] Path where to save the file
      # @return [Integer] Number of bytes written
      def to_file(path)
        # Add schema hint for editor support
        content = "# yaml-language-server: $schema=https://www.expresslang.org/schemas/changes/v1/schema_changes.yaml\n#{to_yaml}"
        File.write(path, content)
      end
    end
  end
end
