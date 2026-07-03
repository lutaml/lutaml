# frozen_string_literal: true

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
        def in_package(package_path_string, recursive: false)
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
        def in_package_indexed(package_path_string, pkg_to_classes, recursive:)
          is_absolute = package_path_string.start_with?("::")
          search_segs = package_path_string.split("::").reject(&:empty?)

          results = []
          pkg_to_classes.each do |path, classes|
            results.concat(classes) if indexed_path_matches?(
              path, package_path_string, is_absolute, search_segs, recursive
            )
          end
          results
        end

        def indexed_path_matches?(path, package_path_string, is_absolute,
                                  search_segs, recursive)
          if is_absolute
            indexed_absolute_match?(path, package_path_string, recursive)
          else
            indexed_relative_match?(path.split("::"), search_segs, recursive)
          end
        end

        def indexed_absolute_match?(path, package_path_string, recursive)
          if recursive
            path == package_path_string ||
              path.start_with?("#{package_path_string}::")
          else
            path == package_path_string
          end
        end

        def indexed_relative_match?(path_segs, search_segs, recursive)
          if recursive
            segments_overlap?(path_segs, search_segs)
          else
            segments_end_with?(path_segs, search_segs)
          end
        end

        # Fallback: original O(n) scan
        def in_package_scan(package_path_string, recursive:)
          package_path = Lutaml::Uml::PackagePath.new(package_path_string)
          is_absolute = package_path.absolute?

          indexes[:qualified_names].each_value.select do |klass|
            scan_matches_package?(klass, package_path, is_absolute, recursive)
          end
        end

        def scan_matches_package?(klass, package_path, is_absolute, recursive)
          qname = resolve_qname_for(klass)
          return false unless qname

          if is_absolute
            match_absolute_path?(qname, package_path, recursive)
          else
            match_relative_path?(qname, package_path, recursive)
          end
        end

        def resolve_qname_for(klass)
          indexes[:qualified_names].find { |_, v| v == klass }&.first
        end

        def match_absolute_path?(qname, package_path, recursive)
          qname = Lutaml::Uml::QualifiedName.new(qname)
          if recursive
            qname.package_path.starts_with?(package_path)
          else
            qname.package_path == package_path
          end
        end

        def match_relative_path?(qname_string, package_path, recursive)
          qname = Lutaml::Uml::QualifiedName.new(qname_string)
          class_pkg_segs = qname.package_path.segments
          search_segs = package_path.segments

          if recursive
            segments_overlap?(class_pkg_segs, search_segs)
          else
            segments_end_with?(class_pkg_segs, search_segs)
          end
        end

        def segments_overlap?(class_segs, search_segs)
          (0..(class_segs.size - search_segs.size)).any? do |i|
            class_segs[i, search_segs.size] == search_segs
          end
        end

        def segments_end_with?(class_segs, search_segs)
          class_segs.size >= search_segs.size &&
            class_segs[-search_segs.size..] == search_segs
        end
      end
    end
  end
end
