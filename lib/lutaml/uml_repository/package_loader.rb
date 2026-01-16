# frozen_string_literal: true

require "zip"
require "yaml"
require_relative "../uml"
require_relative "package_metadata"

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
      def self.load(lur_path) # rubocop:disable Metrics/MethodLength
        unless File.exist?(lur_path)
          raise ArgumentError, "Package file not found: #{lur_path}"
        end

        document = nil
        indexes = nil
        metadata = nil

        begin
          Zip::File.open(lur_path) do |zip|
            # Read metadata (now returns PackageMetadata)
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

        # Create repository with loaded data and metadata
        Repository.new(document: document, indexes: indexes, metadata: metadata)
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
      def self.load_document_only(lur_path) # rubocop:disable Metrics/MethodLength
        unless File.exist?(lur_path)
          raise ArgumentError, "Package file not found: #{lur_path}"
        end

        document = nil
        metadata = nil

        begin
          Zip::File.open(lur_path) do |zip|
            # Read metadata (now returns PackageMetadata)
            metadata = load_metadata(zip)

            # Load Document based on format
            document = load_document(zip, metadata)
          end
        rescue Zip::Error => e
          raise "Invalid LUR package: #{e.message}"
        rescue StandardError => e
          raise "Failed to load package: #{e.message}"
        end

        # Create lazy repository without indexes but with metadata
        require_relative "../lazy_repository"
        LazyRepository.new(document: document, lazy: true, metadata: metadata)
      end

      # Load metadata from the package.
      #
      # @param zip [Zip::File] The ZIP archive
      # @return [PackageMetadata] The package metadata object
      # @raise [RuntimeError] If metadata is missing or invalid
      def self.load_metadata(zip) # rubocop:disable Metrics/AbcSize,Metrics/CyclomaticComplexity,Metrics/MethodLength
        metadata_entry = zip.find_entry("metadata.yaml")
        unless metadata_entry
          raise "Invalid LUR package: missing metadata.yaml"
        end

        # Permit all Lutaml::Uml classes for safe loading
        uml_constants = Lutaml::Uml.constants
        uml_classes = uml_constants.map do |const_name|
          constant_value = Lutaml::Uml.const_get(const_name)
          constant_value if constant_value.is_a?(Class)
        end.compact
        permitted_classes = [Symbol, Time, Date, DateTime, uml_classes].flatten

        # Load full metadata hash (includes operational fields)
        metadata_hash = YAML.safe_load(
          metadata_entry.get_input_stream.read,
          permitted_classes: permitted_classes,
          aliases: true,
        )

        # Extract only PackageMetadata fields and normalize to symbols
        package_fields = %w[
          name version publisher license description keywords
          homepage authors maintainers serialization_format
        ]

        metadata_attrs = {}
        package_fields.each do |field|
          if metadata_hash.key?(field)
            metadata_attrs[field.to_sym] =
              metadata_hash[field]
          end
        end

        # Create PackageMetadata using lutaml-model constructor
        PackageMetadata.new(**metadata_attrs)
      rescue Psych::SyntaxError => e
        raise "Invalid metadata format: #{e.message}"
      end

      # Load the Document from the package.
      #
      # @param zip [Zip::File] The ZIP archive
      # @param metadata [PackageMetadata] The package metadata
      # @return [Lutaml::Uml::Document] The loaded document
      # @raise [RuntimeError] If document is missing or format is unknown
      def self.load_document(zip, metadata) # rubocop:disable Metrics/MethodLength
        # Handle both PackageMetadata object and Hash (backward compatibility)
        format = if metadata.respond_to?(:serialization_format)
                   metadata.serialization_format
                 else
                   metadata["serialization_format"] ||
                     metadata[:serialization_format]
                 end

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
