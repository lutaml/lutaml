# frozen_string_literal: true

require "zip"
require "yaml"
require "time"

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
    # @example Export with custom options
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

      # Initialize a new PackageExporter.
      #
      # @param repository [UmlRepository] The repository to export
      # @param options [Hash] Export options
      # @option options [Symbol] :serialization_format (:marshal) Format for
      #   Document serialization (:marshal or :yaml)
      # @option options [Boolean] :include_xmi (false) Include source XMI
      #   in package
      # @option options [Integer] :compression_level (6) ZIP compression level
      #   (0-9)
      # @option options [String] :name ("UML Model") Package name
      # @option options [String] :version ("1.0") Package version
      def initialize(repository, options = {})
        @repository = repository
        @options = default_options.merge(options)
      end

      # Export the repository to a LUR package file.
      #
      # @param output_path [String] Path for the output .lur file
      # @return [void]
      # @raise [ArgumentError] If serialization format is invalid
      # @example
      #   exporter.export("model.lur")
      def export(output_path)
        validate_options!

        Zip::File.open(output_path, create: true) do |zip|
          write_metadata(zip)
          write_document(zip)
          write_indexes(zip)
          write_statistics(zip)
        end
      end

      private

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
      # @param zip [Zip::File] The ZIP archive
      # @return [void]
      def write_metadata(zip)
        metadata = {
          "name" => @options[:name],
          "version" => @options[:version],
          "created_at" => Time.now.utc.iso8601,
          "created_by" => "lutaml-xmi v#{Lutaml::VERSION}",
          "lutaml_version" => Lutaml::VERSION,
          "serialization_format" => @options[:serialization_format].to_s,
          "statistics" => @repository.statistics,
        }

        zip.get_output_stream("metadata.yaml") do |io|
          io.write(YAML.dump(metadata))
        end
      end

      # Write the Document to the package.
      #
      # @param zip [Zip::File] The ZIP archive
      # @return [void]
      def write_document(zip)
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
