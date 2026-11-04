# frozen_string_literal: true

require "zip"

module Expressir
  module Package
    # Loads LER packages into Repository instances
    # Single responsibility: Load .ler ZIP packages
    class Reader
      # Load repository from LER package
      # @param package_path [String] Path to .ler file
      # @return [Model::Repository] Loaded repository
      def self.load(package_path)
        new.load(package_path)
      end

      # Load repository from LER package
      # @param package_path [String] Path to .ler file
      # @return [Model::Repository] Loaded repository
      def load(package_path)
        unless File.exist?(package_path)
          raise ArgumentError, "Package file not found: #{package_path}"
        end

        repository = nil
        metadata = nil

        Zip::File.open(package_path) do |zip|
          # Read metadata first
          metadata = load_metadata(zip)

          # Load repository based on resolution mode
          repository = if metadata.resolution_mode == "resolved"
                         load_serialized_repository(zip,
                                                    metadata.serialization_format)
                       else
                         load_from_express_files(zip)
                       end

          # Load and restore indexes
          load_indexes(zip, repository)
        end

        repository
      end

      private

      # Load metadata from package
      # @param zip [Zip::File] ZIP archive
      # @return [Metadata] Package metadata
      def load_metadata(zip)
        entry = zip.find_entry("metadata.yaml")
        raise "Metadata not found in package" unless entry

        Metadata.from_yaml(entry.get_input_stream.read)
      end

      # Load serialized repository from package
      # @param zip [Zip::File] ZIP archive
      # @param format [String] Serialization format
      # @return [Model::Repository] Repository instance
      def load_serialized_repository(zip, format)
        case format
        when "marshal"
          load_marshal_repository(zip)
        when "json"
          load_json_repository(zip)
        when "yaml"
          load_yaml_repository(zip)
        else
          raise "Unknown serialization format: #{format}"
        end
      end

      # Load repository from Marshal format
      # @param zip [Zip::File] ZIP archive
      # @return [Model::Repository] Repository instance
      def load_marshal_repository(zip)
        entry = zip.find_entry("repository.marshal")
        raise "Serialized repository not found" unless entry

        Marshal.load(entry.get_input_stream.read)
      end

      # Load repository from JSON format
      # @param zip [Zip::File] ZIP archive
      # @return [Model::Repository] Repository instance
      def load_json_repository(zip)
        entry = zip.find_entry("repository.json")
        raise "Serialized repository not found" unless entry

        Model::Repository.from_json(entry.get_input_stream.read)
      end

      # Load repository from YAML format
      # @param zip [Zip::File] ZIP archive
      # @return [Model::Repository] Repository instance
      def load_yaml_repository(zip)
        entry = zip.find_entry("repository.yaml")
        raise "Serialized repository not found" unless entry

        Model::Repository.from_yaml(entry.get_input_stream.read)
      end

      # Load repository from EXPRESS files
      # @param zip [Zip::File] ZIP archive
      # @return [Model::Repository] Repository instance
      def load_from_express_files(zip)
        repository = Model::Repository.new

        # Find all EXPRESS files in the package
        express_entries = zip.entries.select do |entry|
          entry.name.start_with?("express_files/") && entry.name.end_with?(".exp")
        end

        # Parse each EXPRESS file
        express_entries.each do |entry|
          content = entry.get_input_stream.read
          schema = Expressir::Express::Parser.from_exp(content)
          repository.schemas << schema.schemas.first if schema.schemas.any?
        end

        # Resolve references
        repository.resolve_all_references

        repository
      end

      # Load and restore indexes
      # @param zip [Zip::File] ZIP archive
      # @param repository [Model::Repository] Repository instance
      # @return [void]
      def load_indexes(zip, repository)
        indexes = {}

        %w[entity_index type_index reference_index].each do |name|
          entry = zip.find_entry("#{name}.marshal")
          if entry
            indexes[name.to_sym] =
              Marshal.load(entry.get_input_stream.read)
          end
        end

        repository.restore_indexes(**indexes) unless indexes.empty?
      end
    end
  end
end
