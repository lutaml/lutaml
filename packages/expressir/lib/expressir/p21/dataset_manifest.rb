# frozen_string_literal: true

module Expressir
  module P21
    # A dataset manifest (TODO.instance/03): binds Part 21 files to a
    # schema and a library release, so validation is reproducible.
    class DatasetManifest < Lutaml::Model::Serializable
      attribute :schema, :string
      attribute :release, :string
      attribute :files, :string, collection: true
      attribute :short_names, :hash

      key_value do
        map "schema", to: :schema
        map "release", to: :release
        map "files", to: :files
        map "short_names", to: :short_names
      end

      class << self
        def from_file(path)
          manifest = from_yaml(File.read(path))
          manifest.base_dir = File.dirname(File.expand_path(path))
          manifest.validate_entries!
          manifest
        end
      end

      attr_accessor :base_dir

      # The validator's short-name contract is downcased keys
      # (ISO 10303-21 12.3).
      def short_name_map
        (short_names || {}).transform_keys(&:downcase)
      end

      def file_paths
        Array(files).map { |file| File.expand_path(file, base_dir || ".") }
      end

      def schema_path
        File.expand_path(schema, base_dir || ".")
      end

      # Entries are plain file paths. Structured shapes (the
      # `{path: ...}` mapping of the schema-side manifest) are a
      # different format and must fail at load, not as a TypeError
      # deep in path resolution.
      def validate_entries!
        files.to_a.each_with_index do |file, index|
          next if file.is_a?(String)

          raise Expressir::ManifestValidationError,
                "manifest 'files' entry #{index} is not a plain file " \
                "path; the dataset manifest takes a list of paths " \
                "('files:\\n  - dataset.p21'), not the schema " \
                "manifest's '{path: ...}' entries"
        end
      end
    end
  end
end
