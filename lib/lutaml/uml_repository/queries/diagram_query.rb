# frozen_string_literal: true

require_relative "base_query"
require_relative "../../uml/package_path"

module Lutaml
  module UmlRepository
    module Queries
      # Query service for diagram operations.
      #
      # Provides methods to find and list diagrams from packages using the
      # diagram_index which maps package IDs/paths to diagram collections.
      #
      # @example Finding diagrams in a package
      #   query = DiagramQuery.new(document, indexes)
      #   diagrams = query.in_package("ModelRoot::i-UR::urf")
      #
      # @example Finding a diagram by name
      #   diagram = query.find_by_name("Class Diagram")
      #
      # @example Getting all diagrams
      #   all_diagrams = query.all
      class DiagramQuery < BaseQuery
        # Get diagrams in a specific package.
        #
        # @param package_path_string [String] The package path
        # @return [Array<Diagram>] Array of diagram objects in the package
        # @example
        #   diagrams = query.in_package("ModelRoot::i-UR::urf")
        def in_package(package_path_string)
          return [] if package_path_string.nil? || package_path_string.empty?

          # Try to find diagrams by path
          diagrams = indexes[:diagram_index][package_path_string]
          return diagrams if diagrams

          # Try to find the package and use its ID
          package = indexes[:package_paths][package_path_string]
          return [] unless package

          package_id = package.respond_to?(:xmi_id) ? package.xmi_id : nil
          return [] unless package_id

          indexes[:diagram_index][package_id] || []
        end

        # Find a diagram by its name.
        #
        # Searches all diagrams across all packages for a matching name.
        # Returns the first match found.
        #
        # @param diagram_name [String] The diagram name to search for
        # @return [Diagram, nil] The diagram object, or nil if not found
        # @example
        #   diagram = query.find_by_name("Building Class Diagram")
        def find_by_name(diagram_name)
          return nil if diagram_name.nil? || diagram_name.empty?

          # Search through all diagrams in the index
          indexes[:diagram_index].each_value do |diagrams|
            diagrams.each do |diagram|
              return diagram if diagram.name == diagram_name
            end
          end

          nil
        end

        # Get all diagrams from all packages.
        #
        # @return [Array<Diagram>] Array of all diagram objects
        # @example
        #   all_diagrams = query.all
        #   all_diagrams.each { |d| puts d.name }
        def all
          result = []

          indexes[:diagram_index].each_value do |diagrams|
            result.concat(diagrams)
          end

          result
        end
      end
    end
  end
end
