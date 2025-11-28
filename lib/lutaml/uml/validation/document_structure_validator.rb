# frozen_string_literal: true

require_relative "../../qea/validation/base_validator"

module Lutaml
  module Uml
    module Validation
      # Validates UML document tree structure
      # This validator ensures proper nesting, no duplicate names within same
      # parent, and valid type references in the transformed UML tree
      class DocumentStructureValidator < Qea::Validation::BaseValidator
        def validate
          return unless document

          validate_package_hierarchy(document.packages || [])
          validate_no_duplicate_names
          validate_type_references
        end

        private

        # Validates package hierarchy recursively
        #
        # @param packages [Array<Lutaml::Uml::Package>] Packages to validate
        # @param parent_path [String] Parent package path for context
        # @return [void]
        def validate_package_hierarchy(packages, parent_path = "")
          packages.each do |package|
            current_path = parent_path.empty? ? package.name : "#{parent_path}::#{package.name}"

            # Validate package structure
            validate_package_structure(package, current_path)

            # Recursively validate child packages
            if package.packages && !package.packages.empty?
              validate_package_hierarchy(package.packages, current_path)
            end
          end
        end

        # Validates individual package structure
        #
        # @param package [Lutaml::Uml::Package] Package to validate
        # @param path [String] Package path for error reporting
        # @return [void]
        def validate_package_structure(package, path)
          # Check for required fields
          unless present?(package.name)
            result.add_error(
              category: :invalid_structure,
              entity_type: :package,
              entity_id: package.xmi_id || "unknown",
              entity_name: "Unnamed",
              field: "name",
              message: "Package at path '#{path}' has no name",
            )
          end

          # Validate children collections are arrays
          validate_collection(package, :classes, path)
          validate_collection(package, :enums, path)
          validate_collection(package, :data_types, path)
          validate_collection(package, :packages, path)
          validate_collection(package, :diagrams, path)
        end

        # Validates that a collection attribute is an array
        #
        # @param package [Lutaml::Uml::Package] Package to check
        # @param attribute [Symbol] Attribute name
        # @param path [String] Package path for error reporting
        # @return [void]
        def validate_collection(package, attribute, path)
          value = package.send(attribute)
          unless value.nil? || value.is_a?(Array)
            result.add_error(
              category: :invalid_structure,
              entity_type: :package,
              entity_id: package.xmi_id || "unknown",
              entity_name: package.name,
              field: attribute.to_s,
              message: "Package '#{path}' has invalid #{attribute} " \
                       "(expected Array, got #{value.class})",
            )
          end
        end

        # Validates no duplicate names within same parent
        #
        # @return [void]
        def validate_no_duplicate_names
          return unless document

          # Check top-level entities
          check_duplicate_names_in_collection(
            document.classes || [],
            :class,
            "top-level",
          )
          check_duplicate_names_in_collection(
            document.enums || [],
            :enum,
            "top-level",
          )
          check_duplicate_names_in_collection(
            document.data_types || [],
            :data_type,
            "top-level",
          )
          check_duplicate_names_in_collection(
            document.packages || [],
            :package,
            "top-level",
          )

          # Recursively check packages
          (document.packages || []).each do |package|
            validate_package_duplicates(package, "")
          end
        end

        # Validates no duplicate names within a package recursively
        #
        # @param package [Lutaml::Uml::Package] Package to validate
        # @param parent_path [String] Parent path for context
        # @return [void]
        def validate_package_duplicates(package, parent_path)
          current_path = parent_path.empty? ? package.name : "#{parent_path}::#{package.name}"

          # Check for duplicates within this package
          check_duplicate_names_in_collection(
            package.classes || [],
            :class,
            current_path,
          )
          check_duplicate_names_in_collection(
            package.enums || [],
            :enum,
            current_path,
          )
          check_duplicate_names_in_collection(
            package.data_types || [],
            :data_type,
            current_path,
          )
          check_duplicate_names_in_collection(
            package.packages || [],
            :package,
            current_path,
          )

          # Recursively check child packages
          (package.packages || []).each do |child|
            validate_package_duplicates(child, current_path)
          end
        end

        # Checks for duplicate names in a collection
        #
        # @param collection [Array] Collection to check
        # @param entity_type [Symbol] Type of entities
        # @param context_path [String] Context path for error reporting
        # @return [void]
        def check_duplicate_names_in_collection(collection, entity_type,
context_path)
          name_counts = Hash.new(0)

          collection.each do |entity|
            next unless entity.respond_to?(:name) && entity.name

            name_counts[entity.name] += 1
          end

          name_counts.each do |name, count|
            next if count <= 1

            result.add_warning(
              category: :duplicate_name,
              entity_type: entity_type,
              entity_id: "unknown",
              entity_name: name,
              message: "Duplicate #{entity_type} name '#{name}' found " \
                       "#{count} times in #{context_path}",
            )
          end
        end

        # Validates type references in attributes
        #
        # @return [void]
        def validate_type_references
          return unless document

          all_classes = extract_all_classes_with_path(document)
          all_data_types = extract_all_data_types_with_path(document)
          all_enums = extract_all_enums_with_path(document)

          # Build a set of all valid type names
          valid_types = Set.new
          all_classes.each { |cls, _path| valid_types << cls.name if cls.name }
          all_data_types.each { |dt, _path| valid_types << dt.name if dt.name }
          all_enums.each { |enum, _path| valid_types << enum.name if enum.name }

          # Check attribute type references
          all_classes.each do |cls, path|
            next unless cls.respond_to?(:attributes)

            (cls.attributes || []).each do |attr|
              next unless attr.respond_to?(:type) && attr.type
              next if primitive_type?(attr.type)
              next if valid_types.include?(attr.type)

              result.add_warning(
                category: :invalid_type_reference,
                entity_type: :attribute,
                entity_id: attr.xmi_id || "unknown",
                entity_name: attr.name,
                field: "type",
                reference: attr.type,
                message: "Attribute '#{attr.name}' in class '#{path}' " \
                         "references unknown type '#{attr.type}'",
              )
            end
          end
        end

        # Extracts all classes with their paths
        #
        # @param doc [Lutaml::Uml::Document] Document to extract from
        # @return [Array<Array>] Array of [class, path] pairs
        def extract_all_classes_with_path(doc)
          # Top-level classes
          classes = (doc.classes || []).map do |cls|
            [cls, cls.name || "Unnamed"]
          end

          # Classes in packages
          (doc.packages || []).each do |pkg|
            classes.concat(extract_classes_from_package_with_path(pkg, ""))
          end

          classes
        end

        # Extracts classes from package with path
        #
        # @param package [Lutaml::Uml::Package] Package to extract from
        # @param parent_path [String] Parent path
        # @return [Array<Array>] Array of [class, path] pairs
        def extract_classes_from_package_with_path(package, parent_path)
          classes = []
          current_path = parent_path.empty? ? package.name : "#{parent_path}::#{package.name}"

          (package.classes || []).each do |cls|
            full_path = "#{current_path}::#{cls.name || 'Unnamed'}"
            classes << [cls, full_path]
          end

          (package.packages || []).each do |child|
            classes.concat(extract_classes_from_package_with_path(child,
                                                                  current_path))
          end

          classes
        end

        # Extracts all data types with their paths
        #
        # @param doc [Lutaml::Uml::Document] Document to extract from
        # @return [Array<Array>] Array of [data_type, path] pairs
        def extract_all_data_types_with_path(doc)
          data_types = (doc.data_types || []).map do |dt|
            [dt, dt.name || "Unnamed"]
          end

          (doc.packages || []).each do |pkg|
            data_types.concat(extract_data_types_from_package_with_path(pkg,
                                                                        ""))
          end

          data_types
        end

        # Extracts data types from package with path
        #
        # @param package [Lutaml::Uml::Package] Package to extract from
        # @param parent_path [String] Parent path
        # @return [Array<Array>] Array of [data_type, path] pairs
        def extract_data_types_from_package_with_path(package, parent_path)
          data_types = []
          current_path = parent_path.empty? ? package.name : "#{parent_path}::#{package.name}"

          (package.data_types || []).each do |dt|
            full_path = "#{current_path}::#{dt.name || 'Unnamed'}"
            data_types << [dt, full_path]
          end

          (package.packages || []).each do |child|
            data_types.concat(extract_data_types_from_package_with_path(child,
                                                                        current_path))
          end

          data_types
        end

        # Extracts all enums with their paths
        #
        # @param doc [Lutaml::Uml::Document] Document to extract from
        # @return [Array<Array>] Array of [enum, path] pairs
        def extract_all_enums_with_path(doc)
          enums = (doc.enums || []).map do |enum|
            [enum, enum.name || "Unnamed"]
          end

          (doc.packages || []).each do |pkg|
            enums.concat(extract_enums_from_package_with_path(pkg, ""))
          end

          enums
        end

        # Extracts enums from package with path
        #
        # @param package [Lutaml::Uml::Package] Package to extract from
        # @param parent_path [String] Parent path
        # @return [Array<Array>] Array of [enum, path] pairs
        def extract_enums_from_package_with_path(package, parent_path)
          enums = []
          current_path = parent_path.empty? ? package.name : "#{parent_path}::#{package.name}"

          (package.enums || []).each do |enum|
            full_path = "#{current_path}::#{enum.name || 'Unnamed'}"
            enums << [enum, full_path]
          end

          (package.packages || []).each do |child|
            enums.concat(extract_enums_from_package_with_path(child,
                                                              current_path))
          end

          enums
        end

        # Checks if a type is a primitive type
        #
        # @param type [String] Type name
        # @return [Boolean]
        def primitive_type?(type)
          return false unless type

          primitive_types = %w[
            String Integer Float Boolean Date Time DateTime
            string integer float boolean date time datetime
            int long short byte double char
            void
          ]

          primitive_types.include?(type)
        end
      end
    end
  end
end
