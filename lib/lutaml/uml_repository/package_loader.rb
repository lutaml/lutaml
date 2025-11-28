# frozen_string_literal: true

require "zip"
require "yaml"
require_relative "../uml"

module Lutaml
  module UmlRepository
    # PackageLoader handles loading UmlRepository instances from LUR
    # (LutaML UML Repository) package files.
    #
    # LUR packages are ZIP archives that contain pre-serialized repositories
    # for fast loading without re-parsing XMI files.
    #
    # @example Load from package
    #   repository = PackageLoader.load("model.lur")
    #   klass = repository.find_class("ModelRoot::MyClass")
    class PackageLoader
      # Load a UmlRepository from a LUR package file.
      #
      # @param lur_path [String] Path to the .lur package file
      # @return [UmlRepository] A loaded repository instance
      # @raise [ArgumentError] If the package file doesn't exist
      # @raise [RuntimeError] If the package is invalid or corrupted
      # @example
      #   repo = PackageLoader.load("model.lur")
      def self.load(lur_path)
        unless File.exist?(lur_path)
          raise ArgumentError, "Package file not found: #{lur_path}"
        end

        document = nil
        indexes = nil

        begin
          Zip::File.open(lur_path) do |zip|
            # Read metadata to determine format
            metadata = load_metadata(zip)

            # Load Document based on format
            document = load_document(zip, metadata)

            # Load indexes
            indexes = load_indexes(zip)
          end
        rescue Zip::Error => e
          raise "Invalid LUR package: #{e.message}"
        rescue StandardError => e
          raise "Failed to load package: #{e.message}"
        end

        # Create repository with loaded data
        Repository.new(document: document, indexes: indexes)
      end

      # Load only the document from a LUR package without building indexes.
      #
      # This method loads the document but does not load or build indexes,
      # returning a LazyRepository instance that will build indexes on-demand.
      #
      # @param lur_path [String] Path to the .lur package file
      # @return [LazyRepository] A lazy repository instance
      # @raise [ArgumentError] If the package file doesn't exist
      # @raise [RuntimeError] If the package is invalid or corrupted
      # @example
      #   repo = PackageLoader.load_document_only("model.lur")
      def self.load_document_only(lur_path)
        unless File.exist?(lur_path)
          raise ArgumentError, "Package file not found: #{lur_path}"
        end

        document = nil

        begin
          Zip::File.open(lur_path) do |zip|
            # Read metadata to determine format
            metadata = load_metadata(zip)

            # Load Document based on format
            document = load_document(zip, metadata)
          end
        rescue Zip::Error => e
          raise "Invalid LUR package: #{e.message}"
        rescue StandardError => e
          raise "Failed to load package: #{e.message}"
        end

        # Create lazy repository without indexes
        require_relative "../lazy_repository"
        LazyRepository.new(document: document, lazy: true)
      end

      # Load metadata from the package.
      #
      # @param zip [Zip::File] The ZIP archive
      # @return [Hash] The metadata hash
      # @raise [RuntimeError] If metadata is missing or invalid
      def self.load_metadata(zip)
        metadata_entry = zip.find_entry("metadata.yaml")
        unless metadata_entry
          raise "Invalid LUR package: missing metadata.yaml"
        end

        YAML.safe_load(
          metadata_entry.get_input_stream.read,
          permitted_classes: [Symbol, Time, Date, DateTime],
          aliases: true
        )
      rescue Psych::SyntaxError => e
        raise "Invalid metadata format: #{e.message}"
      end

      # Load the Document from the package.
      #
      # @param zip [Zip::File] The ZIP archive
      # @param metadata [Hash] The package metadata
      # @return [Lutaml::Uml::Document] The loaded document
      # @raise [RuntimeError] If document is missing or format is unknown
      def self.load_document(zip, metadata)
        format = metadata["serialization_format"] ||
          metadata[:serialization_format]

        case format.to_s
        when "yaml"
          load_yaml_document(zip)
        when "marshal"
          load_marshal_document(zip)
        else
          raise "Unknown serialization format: #{format}"
        end
      end

      # Load Document from YAML format.
      #
      # @param zip [Zip::File] The ZIP archive
      # @return [Lutaml::Uml::Document] The loaded document
      # @raise [RuntimeError] If document file is missing
      def self.load_yaml_document(zip)
        entry = zip.find_entry("repository.yaml")
        unless entry
          raise "Invalid LUR package: missing repository.yaml"
        end

        Lutaml::Uml::Document.from_yaml(entry.get_input_stream.read)
      rescue StandardError => e
        raise "Failed to load YAML document: #{e.message}"
      end

      # Load Document from Marshal format.
      #
      # @param zip [Zip::File] The ZIP archive
      # @return [Lutaml::Uml::Document] The loaded document
      # @raise [RuntimeError] If document file is missing
      def self.load_marshal_document(zip)
        entry = zip.find_entry("repository.marshal")
        unless entry
          raise "Invalid LUR package: missing repository.marshal"
        end

        Marshal.load(entry.get_input_stream.read)
      rescue StandardError => e
        raise "Failed to load Marshal document: #{e.message}"
      end

      # Load indexes from the package.
      #
      # @param zip [Zip::File] The ZIP archive
      # @return [Hash] The loaded indexes
      # @raise [RuntimeError] If indexes are missing
      def self.load_indexes(zip)
        entry = zip.find_entry("indexes/all.marshal")
        unless entry
          raise "Invalid LUR package: missing indexes/all.marshal"
        end

        Marshal.load(entry.get_input_stream.read)
      rescue StandardError => e
        raise "Failed to load indexes: #{e.message}"
      end

      private_class_method :load_metadata, :load_document,
                           :load_yaml_document, :load_marshal_document,
                           :load_indexes
    end
  end
end
