# frozen_string_literal: true

module Lutaml
  module UmlRepository
    class IndexBuilder
      # Build the qualified name index
      #
      # Creates a hash mapping qualified names to Class/DataType/Enum objects:
      #   "ModelRoot::i-UR::urf::Building" => Class{}
      # @api public
      def build_qualified_name_index # rubocop:disable Metrics/AbcSize,Metrics/CyclomaticComplexity,Metrics/MethodLength
        # Index top-level classes, data_types, and enums from document
        if @document.classes
          index_classifiers(@document.classes,
                            ROOT_PACKAGE_NAME)
        end
        if @document.data_types
          index_classifiers(@document.data_types,
                            ROOT_PACKAGE_NAME)
        end
        index_classifiers(@document.enums, ROOT_PACKAGE_NAME) if @document.enums

        # Traverse packages and index their classifiers
        traverse_packages(@document.packages,
                          parent_path: ROOT_PACKAGE_NAME) do |package, path|
          index_classifiers(package.classes, path) if package.classes
          index_classifiers(package.data_types, path) if package.data_types
          index_classifiers(package.enums, path) if package.enums
        end
      end

      # Build the stereotype index
      #
      # Creates a hash grouping classes by their stereotype:
      #   "featureType" => [Class{}, Class{}],
      #   "dataType" => [Class{}]
      # @api public
      def build_stereotype_index # rubocop:disable Metrics/AbcSize,Metrics/CyclomaticComplexity
        # Process top-level classes
        index_by_stereotype(@document.classes) if @document.classes
        index_by_stereotype(@document.data_types) if @document.data_types
        index_by_stereotype(@document.enums) if @document.enums

        # Process classes in packages
        traverse_packages(@document.packages) do |package, _path|
          index_by_stereotype(package.classes) if package.classes
          index_by_stereotype(package.data_types) if package.data_types
          index_by_stereotype(package.enums) if package.enums
        end
      end

      # Index classifiers (classes, data types, enums) by their qualified names
      #
      # @param classifiers [Array] Array of classifier objects
      # @param package_path [String] Package path for these classifiers
      def index_classifiers(classifiers, package_path) # rubocop:disable Metrics/MethodLength
        return unless classifiers

        classifiers.each do |classifier|
          next unless classifier.name

          qualified_name = "#{package_path}::#{classifier.name}"
          @qualified_names[qualified_name] = classifier
          if classifier.xmi_id
            @class_to_qname[classifier.xmi_id] =
              qualified_name
          end
          @classes[classifier.xmi_id] = classifier if classifier.xmi_id
          @simple_name_to_qnames[classifier.name] ||= []
          @simple_name_to_qnames[classifier.name] << qualified_name
          (@package_to_classes[package_path] ||= []) << classifier
        end
      end

      # Index classifiers by their stereotypes
      #
      # @param classifiers [Array] Array of classifier objects
      def index_by_stereotype(classifiers) # rubocop:disable Metrics/CyclomaticComplexity
        return unless classifiers

        classifiers.each do |classifier|
          next unless classifier.stereotype && !classifier.stereotype.empty?

          # Handle both String and Array stereotypes
          stereotypes = Array(classifier.stereotype)
          stereotypes.each do |stereotype|
            @stereotypes[stereotype] ||= []
            @stereotypes[stereotype] << classifier
          end
        end
      end
    end
  end
end
