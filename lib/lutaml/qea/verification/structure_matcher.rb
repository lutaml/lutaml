# frozen_string_literal: true

module Lutaml
  module Qea
    module Verification
      # Matches corresponding elements between XMI and QEA documents
      # by qualified name/path
      class StructureMatcher
        # Match packages between documents
        #
        # @param xmi_doc [Lutaml::Uml::Document] XMI document
        # @param qea_doc [Lutaml::Uml::Document] QEA document
        # @return [Hash] Hash with :matches, :xmi_only, :qea_only
        def match_packages(xmi_doc, qea_doc)
          xmi_packages = build_package_index(xmi_doc.packages)
          qea_packages = build_package_index(qea_doc.packages)

          match_elements(xmi_packages, qea_packages)
        end

        # Match classes between documents
        #
        # @param xmi_doc [Lutaml::Uml::Document] XMI document
        # @param qea_doc [Lutaml::Uml::Document] QEA document
        # @return [Hash] Hash with :matches, :xmi_only, :qea_only
        def match_classes(xmi_doc, qea_doc)
          xmi_classes = build_class_index(xmi_doc)
          qea_classes = build_class_index(qea_doc)

          match_elements(xmi_classes, qea_classes)
        end

        # Match attributes between classes
        #
        # @param xmi_class [Lutaml::Uml::Class] XMI class
        # @param qea_class [Lutaml::Uml::Class] QEA class
        # @return [Hash] Hash with :matches, :xmi_only, :qea_only
        def match_attributes(xmi_class, qea_class)
          xmi_attrs = index_by_name(xmi_class.attributes || [])
          qea_attrs = index_by_name(qea_class.attributes || [])

          match_elements(xmi_attrs, qea_attrs)
        end

        # Match operations between classes
        #
        # @param xmi_class [Lutaml::Uml::Class] XMI class
        # @param qea_class [Lutaml::Uml::Class] QEA class
        # @return [Hash] Hash with :matches, :xmi_only, :qea_only
        def match_operations(xmi_class, qea_class)
          xmi_ops = index_by_signature(xmi_class.operations || [])
          qea_ops = index_by_signature(qea_class.operations || [])

          match_elements(xmi_ops, qea_ops)
        end

        # Build qualified name index for document
        #
        # @param document [Lutaml::Uml::Document] The document
        # @return [Hash] Hash mapping qualified names to elements
        def build_qualified_names(document)
          {
            packages: build_package_index(document.packages),
            classes: build_class_index(document),
            enums: build_enum_index(document),
            data_types: build_data_type_index(document),
          }
        end

        private

        # Build package index with qualified paths
        def build_package_index(packages, parent_path = "")
          index = {}
          return index unless packages

          packages.each do |package|
            next unless package.name

            qualified_path = build_path(parent_path, package.name)
            index[qualified_path] = package

            # Recursively index nested packages
            nested = build_package_index(package.packages, qualified_path)
            index.merge!(nested)
          end

          index
        end

        # Build class index from document and packages
        def build_class_index(document)
          index = {}

          # Index top-level classes
          document.classes&.each do |klass|
            next unless klass.name

            index[klass.name] = klass
          end

          # Index classes in packages
          if document.packages
            index_classes_in_packages(document.packages, "",
                                      index)
          end

          index
        end

        # Recursively index classes in packages
        def index_classes_in_packages(packages, parent_path, index)
          return unless packages

          packages.each do |package|
            next unless package.name

            package_path = build_path(parent_path, package.name)

            package.classes&.each do |klass|
              next unless klass.name

              qualified_name = "#{package_path}::#{klass.name}"
              index[qualified_name] = klass
            end

            # Recurse into nested packages
            index_classes_in_packages(package.packages, package_path, index)
          end
        end

        # Build enum index from document and packages
        def build_enum_index(document)
          index = {}

          # Index top-level enums
          document.enums&.each do |enum|
            next unless enum.name

            index[enum.name] = enum
          end

          # Index enums in packages
          if document.packages
            index_enums_in_packages(document.packages, "",
                                    index)
          end

          index
        end

        # Recursively index enums in packages
        def index_enums_in_packages(packages, parent_path, index)
          return unless packages

          packages.each do |package|
            next unless package.name

            package_path = build_path(parent_path, package.name)

            package.enums&.each do |enum|
              next unless enum.name

              qualified_name = "#{package_path}::#{enum.name}"
              index[qualified_name] = enum
            end

            # Recurse into nested packages
            index_enums_in_packages(package.packages, package_path, index)
          end
        end

        # Build data type index from document and packages
        def build_data_type_index(document)
          index = {}

          # Index top-level data types
          document.data_types&.each do |dt|
            next unless dt.name

            index[dt.name] = dt
          end

          # Index data types in packages
          if document.packages
            index_data_types_in_packages(document.packages, "",
                                         index)
          end

          index
        end

        # Recursively index data types in packages
        def index_data_types_in_packages(packages, parent_path, index)
          return unless packages

          packages.each do |package|
            next unless package.name

            package_path = build_path(parent_path, package.name)

            package.data_types&.each do |dt|
              next unless dt.name

              qualified_name = "#{package_path}::#{dt.name}"
              index[qualified_name] = dt
            end

            # Recurse into nested packages
            index_data_types_in_packages(package.packages, package_path, index)
          end
        end

        # Build qualified path from parent and name
        def build_path(parent_path, name)
          return name if parent_path.empty?

          "#{parent_path}::#{name}"
        end

        # Index collection by name
        def index_by_name(collection)
          index = {}
          collection.each do |element|
            next unless element.respond_to?(:name) && element.name

            index[element.name] = element
          end
          index
        end

        # Index operations by signature (name + parameter types)
        def index_by_signature(operations)
          index = {}
          operations.each do |operation|
            next unless operation.name

            signature = build_operation_signature(operation)
            index[signature] = operation
          end
          index
        end

        # Build operation signature for matching
        def build_operation_signature(operation)
          return operation.name unless operation.respond_to?(:parameters)

          param_types = (operation.parameters || []).map do |param|
            param.respond_to?(:type) ? param.type : "unknown"
          end.join(",")

          "#{operation.name}(#{param_types})"
        end

        # Match elements between two indexes
        def match_elements(xmi_index, qea_index)
          matches = {}
          xmi_only = []
          qea_only = []

          # Find matches and XMI-only elements
          xmi_index.each do |key, xmi_element|
            if qea_index.key?(key)
              matches[key] = {
                xmi: xmi_element,
                qea: qea_index[key],
              }
            else
              xmi_only << key
            end
          end

          # Find QEA-only elements
          qea_index.each_key do |key|
            qea_only << key unless xmi_index.key?(key)
          end

          {
            matches: matches,
            xmi_only: xmi_only.sort,
            qea_only: qea_only.sort,
          }
        end
      end
    end
  end
end
