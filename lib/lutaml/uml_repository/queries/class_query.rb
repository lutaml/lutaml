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

            package_path = Lutaml::Uml::PackagePath.new(package_path_string)
            results = []

            # Check if the path is absolute (starts with ModelRoot)
            is_absolute = package_path.absolute?

            indexes[:qualified_names].each do |qname_string, klass| # rubocop:disable Metrics/BlockLength
              qname = Lutaml::Uml::QualifiedName.new(qname_string)

              matched = if is_absolute
                # Absolute path - exact match
                if recursive
                  qname.package_path.starts_with?(package_path)
                else
                  qname.package_path == package_path
                end
              else
                # Relative path - match if the class's package path ends with
                # the given path
                class_pkg_segs = qname.package_path.segments
                search_segs = package_path.segments

                if recursive
                  # For recursive, check if any suffix of the class path
                  # starts with search_segs
                  (0..class_pkg_segs.size - search_segs.size)
                    .any? do |i|
                      class_pkg_segs[i, search_segs.size] == search_segs
                  end
                else
                  # For non-recursive, check if class path ends with
                  # search_segs
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