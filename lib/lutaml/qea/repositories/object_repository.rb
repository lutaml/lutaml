# frozen_string_literal: true

require_relative "base_repository"

module Lutaml
  module Qea
    module Repositories
      # Repository for EaObject collection with type-specific queries
      #
      # This repository provides convenient methods for querying objects
      # by type, package, and other common criteria.
      #
      # @example Query by type
      #   classes = repository.find_by_type("Class")
      #   interfaces = repository.interfaces
      #
      # @example Query by package
      #   pkg_objects = repository.find_by_package(5)
      class ObjectRepository < BaseRepository
        # Find objects by type
        #
        # @param object_type [String] The object type
        # (e.g., "Class", "Interface")
        # @return [Array<Models::EaObject>] Matching objects
        #
        # @example
        #   repository.find_by_type("Class")
        #   repository.find_by_type("Interface")
        def find_by_type(object_type)
          where(object_type: object_type)
        end

        # Find objects by package ID
        #
        # @param package_id [Integer] The package ID
        # @return [Array<Models::EaObject>] Objects in the package
        def find_by_package(package_id)
          where(package_id: package_id)
        end

        # Find objects by stereotype
        #
        # @param stereotype [String] The stereotype name
        # @return [Array<Models::EaObject>] Objects with the stereotype
        def find_by_stereotype(stereotype)
          where(stereotype: stereotype)
        end

        # Get all UML classes
        #
        # @return [Array<Models::EaObject>] All Class objects
        def classes
          find_by_type("Class")
        end

        # Get all interfaces
        #
        # @return [Array<Models::EaObject>] All Interface objects
        def interfaces
          find_by_type("Interface")
        end

        # Get all enumerations
        #
        # @return [Array<Models::EaObject>] All Enumeration objects
        def enumerations
          find_by_type("Enumeration")
        end

        # Get all components
        #
        # @return [Array<Models::EaObject>] All Component objects
        def components
          find_by_type("Component")
        end

        # Get all data types
        #
        # @return [Array<Models::EaObject>] All DataType objects
        def data_types
          find_by_type("DataType")
        end

        # Get all packages
        #
        # @return [Array<Models::EaObject>] All Package objects
        def packages
          find_by_type("Package")
        end

        # Get all abstract objects
        #
        # @return [Array<Models::EaObject>] All abstract objects
        def abstract_objects
          where(&:abstract?)
        end

        # Get all root objects
        #
        # @return [Array<Models::EaObject>] All root objects
        def root_objects
          where(&:root?)
        end

        # Get all leaf objects
        #
        # @return [Array<Models::EaObject>] All leaf objects
        def leaf_objects
          where(&:leaf?)
        end

        # Find objects by name pattern
        #
        # @param pattern [String, Regexp] Name pattern to match
        # @return [Array<Models::EaObject>] Matching objects
        #
        # @example String match
        #   repository.find_by_name("MyClass")
        #
        # @example Regex match
        #   repository.find_by_name(/^Test/)
        def find_by_name(pattern)
          if pattern.is_a?(Regexp)
            where { |obj| obj.name =~ pattern }
          else
            where(name: pattern)
          end
        end

        # Get objects created after a date
        #
        # @param date [String] Date in ISO format
        # @return [Array<Models::EaObject>] Objects created after date
        def created_after(date)
          where { |obj| obj.createddate && obj.createddate > date }
        end

        # Get objects modified after a date
        #
        # @param date [String] Date in ISO format
        # @return [Array<Models::EaObject>] Objects modified after date
        def modified_after(date)
          where { |obj| obj.modifieddate && obj.modifieddate > date }
        end

        # Get statistics by object type
        #
        # @return [Hash<String, Integer>] Count by object type
        #
        # @example
        #   repository.type_statistics
        #   # => {"Class" => 42, "Interface" => 15, ...}
        def type_statistics
          group_by(:object_type).transform_values(&:size)
        end

        # Get statistics by package
        #
        # @return [Hash<Integer, Integer>] Count by package ID
        def package_statistics
          group_by(:package_id).transform_values(&:size)
        end

        # Get all object types in the collection
        #
        # @return [Array<String>] Unique object types
        def object_types
          distinct(:object_type).compact
        end

        # Get all stereotypes in the collection
        #
        # @return [Array<String>] Unique stereotypes
        def stereotypes
          distinct(:stereotype).compact
        end

        # Find objects by visibility
        #
        # @param visibility [String] Visibility (e.g., "Public", "Private")
        # @return [Array<Models::EaObject>] Objects with the visibility
        def find_by_visibility(visibility)
          where(visibility: visibility)
        end

        # Get public objects
        #
        # @return [Array<Models::EaObject>] All public objects
        def public_objects
          find_by_visibility("Public")
        end

        # Get private objects
        #
        # @return [Array<Models::EaObject>] All private objects
        def private_objects
          find_by_visibility("Private")
        end

        # Get protected objects
        #
        # @return [Array<Models::EaObject>] All protected objects
        def protected_objects
          find_by_visibility("Protected")
        end

        # Search objects by name or alias
        #
        # @param query [String] Search query
        # @return [Array<Models::EaObject>] Matching objects
        def search(query)
          query_downcase = query.downcase
          where do |obj|
            obj.name&.downcase&.include?(query_downcase) ||
              obj.alias&.downcase&.include?(query_downcase)
          end
        end
      end
    end
  end
end
