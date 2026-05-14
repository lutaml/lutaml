# frozen_string_literal: true

module Lutaml
  module UmlRepository
    module IndexBuilders
      module ClassIndex
        # Build the qualified name index
        #
        # Creates a hash mapping qualified names to Class/DataType/Enum objects:
        #   "ModelRoot::i-UR::urf::Building" => Class{}
        # @api public
        def build_qualified_name_index
          index_document_classifiers
          index_package_classifiers
        end

        def index_document_classifiers
          if @document.classes
            index_classifiers(@document.classes,
                              IndexBuilder::ROOT_PACKAGE_NAME)
          end
          if @document.data_types
            index_classifiers(@document.data_types,
                              IndexBuilder::ROOT_PACKAGE_NAME)
          end
          if @document.enums
            index_classifiers(@document.enums,
                              IndexBuilder::ROOT_PACKAGE_NAME)
          end
        end

        def index_package_classifiers
          traverse_packages(@document.packages,
                            parent_path: IndexBuilder::ROOT_PACKAGE_NAME) do |package, path|
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
        def build_stereotype_index
          index_document_stereotypes
          index_package_stereotypes
        end

        def index_document_stereotypes
          index_by_stereotype(@document.classes) if @document.classes
          index_by_stereotype(@document.data_types) if @document.data_types
          index_by_stereotype(@document.enums) if @document.enums
        end

        def index_package_stereotypes
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
        def index_classifiers(classifiers, package_path)
          return unless classifiers

          classifiers.each do |classifier|
            next unless classifier.name

            index_classifier(classifier, package_path)
          end
        end

        def index_classifier(classifier, package_path)
          qualified_name = "#{package_path}::#{classifier.name}"
          @qualified_names[qualified_name] = classifier
          if classifier.xmi_id
            @class_to_qname[classifier.xmi_id] =
              qualified_name
          end
          @classes[classifier.xmi_id] = classifier if classifier.xmi_id
          (@simple_name_to_qnames[classifier.name] ||= []) << qualified_name
          (@package_to_classes[package_path] ||= []) << classifier
        end

        # Index classifiers by their stereotypes
        #
        # @param classifiers [Array] Array of classifier objects
        def index_by_stereotype(classifiers)
          return unless classifiers

          classifiers.each do |classifier|
            next unless has_stereotype?(classifier)

            Array(classifier.stereotype).each do |stereotype|
              (@stereotypes[stereotype] ||= []) << classifier
            end
          end
        end

        def has_stereotype?(classifier)
          classifier.stereotype && !classifier.stereotype.empty?
        end
      end
    end
  end
end
