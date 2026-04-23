# frozen_string_literal: true

require "zip"
require "yaml"
require "time"
require_relative "package_metadata"

module Lutaml
  module UmlRepository
    # PackageExporter handles exporting UmlRepository instances to LUR
    # (LutaML UML Repository) package files.
    #
    # LUR packages are ZIP archives containing:
    # - Serialized Document model
    # - Serialized indexes for fast loading
    # - Metadata about the package
    # - Statistics about the model
    #
    # @example Export with defaults
    #   exporter = PackageExporter.new(repository)
    #   exporter.export("model.lur")
    #
    # @example Export with PackageMetadata
    #   metadata = PackageMetadata.new(
    #     name: "Urban Model",
    #     version: "2.0",
    #     publisher: "City Planning",
    #     license: "CC-BY-4.0"
    #   )
    #   exporter = PackageExporter.new(repository, metadata: metadata)
    #   exporter.export("model.lur")
    #
    # @example Export with metadata hash (backward compatible)
    #   exporter = PackageExporter.new(repository,
    #     name: "My Model",
    #     version: "2.0",
    #     serialization_format: :yaml
    #   )
    #   exporter.export("model.lur")
    class PackageExporter
      # @return [UmlRepository] The repository being exported
      attr_reader :repository

      # @return [Hash] Export options
      attr_reader :options

      # @return [PackageMetadata] The package metadata
      attr_reader :metadata

      # Initialize a new PackageExporter.
      #
      # @param repository [UmlRepository] The repository to export
      # @param options [Hash] Export options
      # @option options [PackageMetadata, Hash] :metadata Package metadata
      #   (can be PackageMetadata object or Hash)
      # @option options [Symbol] :serialization_format (:marshal) Format for
      #   Document serialization (:marshal or :yaml)
      # @option options [Boolean] :include_xmi (false) Include source XMI
      #   in package
      # @option options [Integer] :compression_level (6) ZIP compression level
      #   (0-9)
      # @option options [String] :name ("UML Model") Package name
      #   (deprecated, use :metadata)
      # @option options [String] :version ("1.0") Package version
      #   (deprecated, use :metadata)
      def initialize(repository, options = {})
        @repository = repository
        @options = default_options.merge(options)
        @metadata = build_metadata(@options)
      end

      # Export the repository to a LUR package file.
      #
      # @param output_path [String] Path for the output .lur file
      # @return [void]
      # @raise [ArgumentError] If serialization format is invalid
      # @example
      #   exporter.export("model.lur")
      def export(output_path) # rubocop:disable Metrics/MethodLength
        validate_options!

        retries = 0
        begin
          write_lur_package(output_path)
        rescue Errno::EACCES
          retries += 1
          retry if retries < 3
          raise
        end
      end

      private

      def write_lur_package(output_path)
        Zip::File.open(output_path, create: true) do |zip|
          write_metadata(zip)
          write_document(zip)
          write_indexes(zip)
          write_index_tree(zip)
          write_statistics(zip)
        end
      end

      # Get default export options.
      #
      # @return [Hash] Default options
      def default_options
        {
          serialization_format: :marshal,
          include_xmi: false,
          compression_level: 6,
          name: "UML Model",
          version: "1.0",
        }
      end

      # Build PackageMetadata from options.
      #
      # Handles three cases:
      # 1. :metadata is a PackageMetadata object - use directly
      # 2. :metadata is a Hash - build from hash
      # 3. Old-style :name/:version options - build from those
      #
      # @param options [Hash] Export options
      # @return [PackageMetadata] Package metadata
      def build_metadata(options) # rubocop:disable Metrics/AbcSize,Metrics/MethodLength
        # Case 1: metadata is already a PackageMetadata object
        if options[:metadata].is_a?(PackageMetadata)
          return options[:metadata]
        end

        # Case 2: metadata is a Hash
        if options[:metadata].is_a?(Hash)
          metadata_hash = options[:metadata].dup
          # Ensure serialization_format is set
          metadata_hash[:serialization_format] ||=
            options[:serialization_format]
          # Normalize keys to symbols and create directly
          normalized = metadata_hash.transform_keys(&:to_sym)
          return PackageMetadata.new(**normalized)
        end

        # Case 3: Old-style options (backward compatibility)
        PackageMetadata.new(
          name: options[:name],
          version: options[:version],
          serialization_format: options[:serialization_format].to_s,
        )
      end

      # Validate export options.
      #
      # @return [void]
      # @raise [ArgumentError] If options are invalid
      def validate_options!
        format = @options[:serialization_format]
        unless %i[marshal yaml].include?(format)
          raise ArgumentError,
                "Invalid serialization format: #{format}. " \
                "Must be :marshal or :yaml"
        end
      end

      # Write metadata.yaml to the package.
      #
      # Converts PackageMetadata to YAML hash, then adds operational
      # metadata (created_at, created_by, etc.).
      #
      # @param zip [Zip::File] The ZIP archive
      # @return [void]
      def write_metadata(zip) # rubocop:disable Metrics/AbcSize,Metrics/MethodLength
        # Convert PackageMetadata to hash via YAML round-trip
        metadata_hash = YAML.safe_load(@metadata.to_yaml)

        # Add operational metadata (not in PackageMetadata model)
        metadata_hash["created_at"] = Time.now.utc.iso8601
        metadata_hash["created_by"] = "lutaml-xmi v#{Lutaml::VERSION}"
        metadata_hash["lutaml_version"] = Lutaml::VERSION
        metadata_hash["statistics"] = @repository.statistics

        # Ensure serialization_format is set
        metadata_hash["serialization_format"] ||=
          @options[:serialization_format].to_s

        zip.get_output_stream("metadata.yaml") do |io|
          io.write(YAML.dump(metadata_hash))
        end
      end

      # Write the Document to the package.
      #
      # @param zip [Zip::File] The ZIP archive
      # @return [void]
      def write_document(zip) # rubocop:disable Metrics/MethodLength
        format = @options[:serialization_format]

        case format
        when :yaml
          zip.get_output_stream("repository.yaml") do |io|
            io.write(@repository.document.to_yaml)
          end
        when :marshal
          zip.get_output_stream("repository.marshal") do |io|
            io.write(Marshal.dump(@repository.document))
          end
        end
      end

      # Write indexes to the package.
      #
      # @param zip [Zip::File] The ZIP archive
      # @return [void]
      def write_indexes(zip)
        zip.get_output_stream("indexes/all.marshal") do |io|
          io.write(Marshal.dump(@repository.indexes))
        end
      end

      # Write index tree (searchable list of all model elements) to the package.
      #
      # @param zip [Zip::File] The ZIP archive
      # @return [void]
      def write_index_tree(zip)
        tree = build_index_tree

        zip.get_output_stream("index_tree.yaml") do |io|
          io.write(YAML.dump(tree))
        end
      end

      # Build a complete index tree of all model elements
      #
      # @return [Hash] Index tree structure
      def build_index_tree # rubocop:disable Metrics/MethodLength
        {
          "format" => "lutaml_index_tree_v1",
          "generated_at" => Time.now.utc.iso8601,
          "packages" => build_packages_index,
          "classes" => build_classes_index,
          "summary" => {
            "total_packages" => @repository.indexes[:package_paths].size,
            "total_classes" => @repository.indexes[:qualified_names].size,
            "total_attributes" => count_all_attributes,
          },
        }
      end

      # Build packages index
      #
      # @return [Hash] Packages indexed by path
      def build_packages_index # rubocop:disable Metrics/MethodLength
        packages = {}
        @repository.indexes[:package_paths].each do |path, package|
          next unless package.is_a?(Lutaml::Uml::Package)

          packages[path] = {
            "name" => package.name,
            "xmi_id" => package.xmi_id,
            "classes_count" => @repository
              .classes_in_package(path, recursive: false).size,
            "diagrams_count" => package.diagrams&.size || 0,
          }
        end
        packages
      end

      # Build classes index
      #
      # @return [Hash] Classes indexed by qualified name
      def build_classes_index # rubocop:disable Metrics/MethodLength
        classes = {}
        @repository.indexes[:qualified_names].each do |qname, klass|
          classes[qname] = {
            "name" => klass.name,
            "xmi_id" => klass.xmi_id,
            "type" => klass.class.name.split("::").last, # Class, DataType, Enum
            "stereotype" => format_stereotype(klass.stereotype),
            "attributes" => build_attributes_list(klass),
            "package_path" => extract_package_path(qname),
          }
        end
        classes
      end

      # Build attributes list for a class
      #
      # @param klass [Object] The class object
      # @return [Array<Hash>] List of attributes
      def build_attributes_list(klass)
        return [] unless klass.respond_to?(:attributes) && klass.attributes

        klass.attributes.map do |attr|
          {
            "name" => attr.name,
            "type" => attr.type,
            "visibility" => if attr.respond_to?(:visibility)
                              attr.visibility
                            end,
          }.compact
        end
      end

      # Format stereotype for consistent output
      #
      # @param stereotype [String, Array, nil] Stereotype value
      # @return [String, Array, nil] Formatted stereotype
      def format_stereotype(stereotype)
        return nil if stereotype.nil?
        return stereotype if stereotype.is_a?(String)

        stereotype.is_a?(Array) && stereotype.empty? ? nil : stereotype
      end

      # Extract package path from qualified name
      #
      # @param qname [String] Qualified name
      # @return [String] Package path
      def extract_package_path(qname)
        parts = qname.split("::")
        parts.size > 1 ? parts[0..-2].join("::") : "ModelRoot"
      end

      # Count all attributes across all classes
      #
      # @return [Integer] Total attribute count
      def count_all_attributes
        total = 0
        @repository.indexes[:qualified_names].each_value do |klass|
          if klass.respond_to?(:attributes) && klass.attributes
            total += klass.attributes.size
          end
        end
        total
      end

      # Write statistics to the package.
      #
      # @param zip [Zip::File] The ZIP archive
      # @return [void]
      def write_statistics(zip)
        zip.get_output_stream("statistics.yaml") do |io|
          io.write(YAML.dump(@repository.statistics))
        end
      end
    end
  end
end
