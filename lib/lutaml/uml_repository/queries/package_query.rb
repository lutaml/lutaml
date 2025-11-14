# frozen_string_literal: true

require_relative "base_query"
require_relative "../../uml/package_path"

module Lutaml
  module UmlRepository
    module Queries
      # Query service for package operations.
      #
      # Provides methods to find, list, and navigate package hierarchies
      # using the package_paths index for efficient lookups.
      #
      # @example Finding a package by path
      #   query = PackageQuery.new(document, indexes)
      #   package = query.find_by_path("ModelRoot::i-UR::urf")
      #
      # @example Listing child packages
      #   packages = query.list("ModelRoot::i-UR", recursive: false)
      #
      # @example Building a package tree
      #   tree = query.tree("ModelRoot", max_depth: 2)
      class PackageQuery < BaseQuery
        # Find a single package by its path.
        #
        # Supports multiple search strategies:
        # 1. Exact full path match (e.g., "ModelRoot::i-UR::uro")
        # 2. Simple name match (e.g., "uro")
        # 3. Partial path match (e.g., "i-UR::uro")
        #
        # @param path_string [String] The package path (e.g., "ModelRoot::i-UR")
        # @return [Lutaml::Uml::Package, Lutaml::Uml::Document, nil] The package
        #   or document, or nil if not found
        # @example Exact path
        #   package = query.find_by_path("ModelRoot::i-UR::urf")
        #
        # @example Simple name
        #   package = query.find_by_path("urf")
        #
        # @example Partial path
        #   package = query.find_by_path("i-UR::urf")
        def find_by_path(path_string)
          return nil if path_string.nil? || path_string.empty?

          # Strategy 1: Try exact match first (most common case)
          exact_match = indexes[:package_paths][path_string]
          return exact_match if exact_match

          # Strategy 2 & 3: Search for simple name or partial path match
          search_segments = path_string.split("::")
          matches = []

          indexes[:package_paths].each do |full_path, package|
            full_segments = full_path.split("::")

            # Simple name match: last segment matches
            if search_segments.length == 1
              matches << package if full_segments.last == search_segments.first
            # Partial path match: ends with search path
            elsif full_segments.last(search_segments.length) == search_segments
              matches << package
            end
          end

          # Return single match, or nil if no match or ambiguous
          matches.length == 1 ? matches.first : nil
        end

        # List packages at a specific path.
        #
        # @param parent_path_string [String] The parent package path
        # @param recursive [Boolean] Whether to include nested packages
        #   recursively (default: false)
        # @return [Array<Lutaml::Uml::Package>] Array of packages
        # @example Non-recursive listing
        #   packages = query.list("ModelRoot::i-UR", recursive: false)
        #   # Returns only direct children of i-UR
        #
        # @example Recursive listing
        #   packages = query.list("ModelRoot", recursive: true)
        #   # Returns all packages under ModelRoot
        def list(parent_path_string, recursive: false)
          return [] if parent_path_string.nil? || parent_path_string.empty?

          parent_path = Lutaml::Uml::PackagePath.new(parent_path_string)
          results = []

          indexes[:package_paths].each do |path_string, package|
            path = Lutaml::Uml::PackagePath.new(path_string)

            # Skip the parent itself
            next if path == parent_path

            # Check if this path is under the parent
            next unless path.starts_with?(parent_path)

            if recursive
              # Include all descendants
              results << package
            elsif path.depth == parent_path.depth + 1
              # Include only direct children (depth = parent_depth + 1)
              results << package
            end
          end

          results
        end

        # Build a hierarchical tree structure of packages.
        #
        # @param root_path_string [String] The root package path to start from
        # @param max_depth [Integer, nil] Maximum depth to traverse (nil for
        #   unlimited)
        # @return [Hash, nil] Tree structure with package information, or nil
        #   if root not found
        # @example
        #   tree = query.tree("ModelRoot::i-UR", max_depth: 2)
        #   # => {
        #   #   name: "i-UR",
        #   #   path: "ModelRoot::i-UR",
        #   #   classes_count: 0,
        #   #   diagrams_count: 0,
        #   #   children: [
        #   #     {
        #   #       name: "urf",
        #   #       path: "ModelRoot::i-UR::urf",
        #   #       classes_count: 15,
        #   #       diagrams_count: 2,
        #   #       children: []
        #   #     }
        #   #   ]
        #   # }
        def tree(root_path_string, max_depth: nil)
          return nil if root_path_string.nil? || root_path_string.empty?

          root_package = find_by_path(root_path_string)
          return nil unless root_package

          build_tree_node(root_path_string, root_package, max_depth, 0)
        end

        private

        # Build a tree node for a package
        #
        # @param path_string [String] The package path
        # @param package [Lutaml::Uml::Package, Lutaml::Uml::Document] The
        #   package or document object
        # @param max_depth [Integer, nil] Maximum depth to traverse
        # @param current_depth [Integer] Current depth in the tree
        # @return [Hash] Tree node structure
        def build_tree_node(path_string, package, max_depth, current_depth)
          path = Lutaml::Uml::PackagePath.new(path_string)

          node = {
            name: path.segments.last,
            path: path_string,
            classes_count: count_classes(package),
            diagrams_count: count_diagrams(package),
            children: [],
          }

          # Stop if we've reached max depth
          if max_depth.nil? || current_depth < max_depth
            # Find direct children
            children = list(path_string, recursive: false)
            children.each do |child_package|
              child_path = find_package_path(child_package, path_string)
              next unless child_path

              child_node = build_tree_node(
                child_path,
                child_package,
                max_depth,
                current_depth + 1,
              )
              node[:children] << child_node
            end
          end

          node
        end

        # Count classes in a package
        #
        # @param package [Lutaml::Uml::Package, Lutaml::Uml::Document] The package
        # @return [Integer] Number of classes
        def count_classes(package)
          count = 0
          count += package.classes.size if package.respond_to?(:classes) && package.classes
          count += package.data_types.size if package.respond_to?(:data_types) && package.data_types
          count += package.enums.size if package.respond_to?(:enums) && package.enums
          count
        end

        # Count diagrams in a package
        #
        # @param package [Lutaml::Uml::Package, Lutaml::Uml::Document] The package
        # @return [Integer] Number of diagrams
        def count_diagrams(package)
          return 0 unless package.respond_to?(:diagrams) && package.diagrams

          package.diagrams.size
        end

        # Find the path of a package under a parent path
        #
        # @param package [Lutaml::Uml::Package] The package to find
        # @param parent_path_string [String] The parent package path
        # @return [String, nil] The package path, or nil if not found
        def find_package_path(package, parent_path_string)
          parent_path = Lutaml::Uml::PackagePath.new(parent_path_string)

          # Search for this package in the index
          indexes[:package_paths].each do |path_string, indexed_package|
            next unless indexed_package == package

            path = Lutaml::Uml::PackagePath.new(path_string)
            # Check if it's a direct child of parent_path
            if path.starts_with?(parent_path) && path.depth == parent_path.depth + 1
              return path_string
            end
          end

          nil
        end
      end
    end
  end
end
