# frozen_string_literal: true

module Lutaml
  module Qea
    module Verification
      # Normalizes UML documents for comparison by removing XMI IDs,
      # sorting collections, and normalizing strings
      class DocumentNormalizer
        # Normalize a document for comparison
        #
        # @param document [Lutaml::Uml::Document] The document to normalize
        # @return [Lutaml::Uml::Document] A normalized copy
        def normalize(document)
          normalized = deep_copy(document)
          remove_xmi_ids(normalized)
          sort_collections(normalized)
          normalize_strings_in_document(normalized)
          normalized
        end

        # Remove all XMI IDs from document
        #
        # @param document [Lutaml::Uml::Document] The document to process
        # @return [void]
        def remove_xmi_ids(document)
          # Remove XMI IDs from packages recursively
          process_packages(document.packages) if document.packages

          # Remove XMI IDs from classes
          process_classes(document.classes) if document.classes

          # Remove XMI IDs from associations
          process_associations(document.associations) if document.associations

          # Remove XMI IDs from enums
          process_enums(document.enums) if document.enums

          # Remove XMI IDs from data types
          process_data_types(document.data_types) if document.data_types
        end

        # Sort collections in document for consistent comparison
        #
        # @param document [Lutaml::Uml::Document] The document to process
        # @return [void]
        def sort_collections(document)
          # Sort top-level collections by name
          document.packages&.sort_by! { |p| p.name || "" }
          document.classes&.sort_by! { |c| c.name || "" }
          document.enums&.sort_by! { |e| e.name || "" }
          document.data_types&.sort_by! { |dt| dt.name || "" }
          document.associations&.sort_by! do |a|
            "#{a.owner_end}#{a.member_end}"
          end

          # Sort nested collections recursively
          sort_package_collections(document.packages) if document.packages
          sort_class_collections(document.classes) if document.classes
        end

        # Normalize strings (trim whitespace, normalize case for comparison)
        #
        # @param text [String, nil] The text to normalize
        # @return [String, nil] Normalized text
        def normalize_string(text)
          return nil if text.nil?
          return text unless text.is_a?(String)

          text.strip
        end

        private

        # Deep copy document to avoid modifying original
        def deep_copy(document)
          # Use YAML serialization for deep copy
          yaml = document.to_yaml
          Lutaml::Uml::Document.from_yaml(yaml)
        end

        # Process packages recursively to remove XMI IDs
        def process_packages(packages)
          packages.each do |package|
            package.xmi_id = nil if package.respond_to?(:xmi_id=)
            process_classes(package.classes) if package.classes
            process_enums(package.enums) if package.enums
            process_data_types(package.data_types) if package.data_types
            process_packages(package.packages) if package.packages
          end
        end

        # Process classes to remove XMI IDs
        def process_classes(classes)
          classes.each do |klass|
            klass.xmi_id = nil if klass.respond_to?(:xmi_id=)

            # Remove XMI IDs from attributes
            klass.attributes&.each do |attr|
              attr.xmi_id = nil if attr.respond_to?(:xmi_id=)
            end

            # Remove XMI IDs from operations
            klass.operations&.each do |op|
              op.xmi_id = nil if op.respond_to?(:xmi_id=)
              op.parameters&.each do |param|
                param.xmi_id = nil if param.respond_to?(:xmi_id=)
              end
            end

            # Process nested classes
            process_classes(klass.classes) if klass.respond_to?(:classes) && klass.classes
          end
        end

        # Process associations to remove XMI IDs
        def process_associations(associations)
          associations.each do |assoc|
            assoc.xmi_id = nil if assoc.respond_to?(:xmi_id=)
            assoc.owner_end_xmi_id = nil if assoc.respond_to?(:owner_end_xmi_id=)
            assoc.member_end_xmi_id = nil if assoc.respond_to?(:member_end_xmi_id=)
          end
        end

        # Process enums to remove XMI IDs
        def process_enums(enums)
          enums.each do |enum|
            enum.xmi_id = nil if enum.respond_to?(:xmi_id=)
            enum.owned_literals&.each do |literal|
              literal.xmi_id = nil if literal.respond_to?(:xmi_id=)
            end
          end
        end

        # Process data types to remove XMI IDs
        def process_data_types(data_types)
          data_types.each do |dt|
            dt.xmi_id = nil if dt.respond_to?(:xmi_id=)
          end
        end

        # Sort collections within packages
        def sort_package_collections(packages)
          packages.each do |package|
            package.classes&.sort_by! { |c| c.name || "" }
            package.enums&.sort_by! { |e| e.name || "" }
            package.data_types&.sort_by! { |dt| dt.name || "" }
            package.packages&.sort_by! { |p| p.name || "" }

            sort_class_collections(package.classes) if package.classes
            sort_package_collections(package.packages) if package.packages
          end
        end

        # Sort collections within classes
        def sort_class_collections(classes)
          classes.each do |klass|
            klass.attributes&.sort_by! { |a| a.name || "" }
            klass.operations&.sort_by! { |o| o.name || "" }
            klass.associations&.sort_by! do |a|
              "#{a.owner_end}#{a.member_end}"
            end
          end
        end

        # Normalize strings throughout document
        def normalize_strings_in_document(document)
          # This is a placeholder for string normalization
          # Can be extended to normalize strings throughout the document
          # For now, normalization happens during comparison
        end
      end
    end
  end
end
