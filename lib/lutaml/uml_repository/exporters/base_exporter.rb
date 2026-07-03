# frozen_string_literal: true

module Lutaml
  module UmlRepository
    module Exporters
      # Base class for all exporters.
      #
      # Exporters convert a UmlRepository to various formats such as CSV,
      # JSON, Markdown, etc. All exporters inherit from this base class and
      # implement the [`export`](#export) method.
      #
      # @example Creating a custom exporter
      #   class MyExporter < BaseExporter
      #     def export(output_path, options = {})
      #       # Implementation here
      #     end
      #   end
      #
      #   exporter = MyExporter.new(repository)
      #   exporter.export("output.txt")
      class BaseExporter
        # @return [UmlRepository] The repository to export
        attr_reader :repository

        # Initialize a new exporter.
        #
        # @param repository [UmlRepository] The repository to export
        def initialize(repository)
          @repository = repository
        end

        # Export the repository to a file.
        #
        # @param output_path [String] Path to the output file
        # @param options [Hash] Export options (exporter-specific)
        # @raise [NotImplementedError] Must be implemented by subclasses
        # @return [void]
        def export(output_path, options = {})
          raise NotImplementedError,
                "#{self.class.name} must implement #export"
        end

        private

        # Get the document from the repository.
        #
        # @return [Lutaml::Uml::Document] The UML document
        def document
          @repository.document
        end

        # Get the indexes from the repository.
        #
        # @return [Hash] The repository indexes
        def indexes
          @repository.indexes
        end
      end
    end
  end
end
