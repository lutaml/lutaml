# frozen_string_literal: true

require_relative "base_query"
require_relative "../../uml/qualified_name"
require_relative "../../uml/package_path"

module Lutaml
  module UmlRepository
    module Queries
      # Query service for class/classifier operations.
      #
      # Provides methods to find and query classes, data types, and enums
      # using the qualified_names and stereotypes indexes.
      #
      # @example Finding a class by qualified name
      #   query = ClassQuery.new(document, indexes)
      #   klass = query.find_by_qname("ModelRoot::i-UR::urf::Building")
      #
      # @example Finding classes by stereotype
      #   classes = query.find_by_stereotype("featureType")
      #
      # @example Getting classes in a package
      #   classes = query.in_package("ModelRoot::i-UR::urf")
      class ClassQuery < BaseQuery
        # Find a class by its qualified name.
        #
        # @param qualified_name_string [String] The qualified name
        #   (e.g., "ModelRoot::i-UR::urf::Building")
        # @return [Lutaml::Uml::Class, Lutaml::Uml::DataType,
        # Lutaml::Uml::Enum, nil]
        #   The class object, or nil if not found
        # @example
        #   klass = query.find_by_qname("ModelRoot::i-UR::urf::Building")
        def find_by_qname(qualified_name_string)
          if qualified_name_string.nil? || qualified_name_string.empty?
            return nil
          end

          indexes[:qualified_names][qualified_name_string]
        end

        # Find all classes with a specific stereotype.
        #
        # @param stereotype [String] The stereotype to search for
        # @return [Array] Array of class objects with the stereotype
        # @example
        #   feature_types = query.find_by_stereotype("featureType")
        #   # => [Class{name: "Building"}, Class{name: "Road"}, ...]
        def find_by_stereotype(stereotype)
          return [] if stereotype.nil? || stereotype.empty?

          indexes[:stereotypes][stereotype] || []
        end

        # Get classes in a specific package.
        #
        # @param package_path_string [String] The package path
        # @param recursive [Boolean] Whether to include classes from nested
        #   packages (default: false)
        # @return [Array] Array of class objects in the package
        # @example Non-recursive query
        #   classes = query.in_package(
        #   "ModelRoot::i-UR::urf", recursive: false)
        #   # Returns only classes directly in the urf package
        #
        # @example Recursive query
        #   classes = query.in_package("ModelRoot::i-UR", recursive: true)
        #   # Returns classes in i-UR and all nested packages
        def in_package(package_path_string, recursive: false) # rubocop:disable Metrics/AbcSize,Metrics/CyclomaticComplexity,Metrics/MethodLength,Metrics/PerceivedComplexity
          return [] if package_path_string.nil? || package_path_string.empty?

          pkg_to_classes = indexes[:package_to_classes]
          if pkg_to_classes
            in_package_indexed(package_path_string, pkg_to_classes,
                               recursive: recursive)
          else
            in_package_scan(package_path_string, recursive: recursive)
          end
        end

        private

        # O(1) indexed lookup for in_package
        def in_package_indexed(package_path_string, pkg_to_classes, recursive:) # rubocop:disable Metrics/AbcSize,Metrics/CyclomaticComplexity,Metrics/PerceivedComplexity
          is_absolute = package_path_string.start_with?("::")
          search_segs = package_path_string.split("::").reject(&:empty?)

          results = []
          pkg_to_classes.each do |path, classes|
            path_segs = path.split("::")
            matched = if is_absolute
                        if recursive
                          path == package_path_string ||
                            path.start_with?("#{package_path_string}::")
                        else
                          path == package_path_string
                        end
                      else
                        # Relative: match when path ends with search segments
                        if recursive
                          (0..(path_segs.size - search_segs.size)).any? do |i|
                            path_segs[i, search_segs.size] == search_segs
                          end
                        else
                          path_segs.size >= search_segs.size &&
                            path_segs[-search_segs.size..] == search_segs
                        end
                      end

            results.concat(classes) if matched
          end
          results
        end

        # Fallback: original O(n) scan
        def in_package_scan(package_path_string, recursive:)
          package_path = Lutaml::Uml::PackagePath.new(package_path_string)
          results = []
          is_absolute = package_path.absolute?

          indexes[:qualified_names].each do |qname_string, klass|
            qname = Lutaml::Uml::QualifiedName.new(qname_string)

            matched = if is_absolute
                        if recursive
                          qname.package_path.starts_with?(package_path)
                        else
                          qname.package_path == package_path
                        end
                      else
                        class_pkg_segs = qname.package_path.segments
                        search_segs = package_path.segments

                        if recursive
                          (0..(class_pkg_segs.size - search_segs.size))
                            .any? do |i|
                            class_pkg_segs[i, search_segs.size] == search_segs
                          end
                        else
                          class_pkg_segs.size >= search_segs.size &&
                            class_pkg_segs[-search_segs.size..] == search_segs
                        end
                      end

            results << klass if matched
          end

          results
        end
      end
    end
  end
end
