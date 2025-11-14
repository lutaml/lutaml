# frozen_string_literal: true

require_relative "document_normalizer"
require_relative "structure_matcher"
require_relative "element_comparator"
require_relative "comparison_result"
require_relative "../../qea"
require_relative "../../parser"

module Lutaml
  module Qea
    module Verification
      # Main orchestrator for document verification
      # Verifies that QEA-parsed documents contain at least as much
      # information as XMI-parsed equivalents
      class DocumentVerifier
        attr_reader :normalizer, :matcher, :comparator, :result

        def initialize
          @normalizer = DocumentNormalizer.new
          @matcher = StructureMatcher.new
          @comparator = ElementComparator.new
          @result = ComparisonResult.new
        end

        # Main verification method
        #
        # @param xmi_path [String] Path to XMI file
        # @param qea_path [String] Path to QEA file
        # @return [ComparisonResult] Verification result
        def verify(xmi_path, qea_path)
          # Parse documents
          xmi_doc = parse_xmi(xmi_path)
          qea_doc = parse_qea(qea_path)

          # Normalize documents
          xmi_normalized = normalizer.normalize(xmi_doc)
          qea_normalized = normalizer.normalize(qea_doc)

          # Perform verification
          verify_structure(xmi_normalized, qea_normalized)
          verify_names(xmi_normalized, qea_normalized)
          verify_properties(xmi_normalized, qea_normalized)
          verify_relationships(xmi_normalized, qea_normalized)

          result
        end

        # Verify document with already loaded documents
        #
        # @param xmi_doc [Lutaml::Uml::Document] XMI document
        # @param qea_doc [Lutaml::Uml::Document] QEA document
        # @return [ComparisonResult] Verification result
        def verify_documents(xmi_doc, qea_doc)
          # Normalize documents
          xmi_normalized = normalizer.normalize(xmi_doc)
          qea_normalized = normalizer.normalize(qea_doc)

          # Perform verification
          verify_structure(xmi_normalized, qea_normalized)
          verify_names(xmi_normalized, qea_normalized)
          verify_properties(xmi_normalized, qea_normalized)
          verify_relationships(xmi_normalized, qea_normalized)

          result
        end

        # Compare element counts
        #
        # @param xmi_doc [Lutaml::Uml::Document] XMI document
        # @param qea_doc [Lutaml::Uml::Document] QEA document
        # @return [void]
        def verify_structure(xmi_doc, qea_doc)
          # Compare package counts
          match_result = matcher.match_packages(xmi_doc, qea_doc)
          result.add_matches(:packages, match_result[:matches].size)
          result.add_xmi_only(:packages, match_result[:xmi_only])
          result.add_qea_only(:packages, match_result[:qea_only])

          # Compare class counts
          match_result = matcher.match_classes(xmi_doc, qea_doc)
          result.add_matches(:classes, match_result[:matches].size)
          result.add_xmi_only(:classes, match_result[:xmi_only])
          result.add_qea_only(:classes, match_result[:qea_only])

          # Compare enum counts
          xmi_enums = count_all_enums(xmi_doc)
          qea_enums = count_all_enums(qea_doc)
          if qea_enums < xmi_enums
            result.add_difference(
              "Enums: #{xmi_enums} (XMI) vs #{qea_enums} (QEA) - QEA has fewer",
            )
          end

          # Compare data type counts
          xmi_dt = count_all_data_types(xmi_doc)
          qea_dt = count_all_data_types(qea_doc)
          if qea_dt < xmi_dt
            result.add_difference(
              "Data types: #{xmi_dt} (XMI) vs #{qea_dt} (QEA) - QEA has fewer",
            )
          end

          # Compare association counts
          xmi_assocs = count_all_associations(xmi_doc)
          qea_assocs = count_all_associations(qea_doc)
          result.add_matches(:associations, [xmi_assocs, qea_assocs].min)
          if qea_assocs < xmi_assocs
            result.add_difference(
              "Associations: #{xmi_assocs} (XMI) vs #{qea_assocs} (QEA) - QEA has fewer",
            )
          end
        end

        # Verify element names are preserved
        #
        # @param xmi_doc [Lutaml::Uml::Document] XMI document
        # @param qea_doc [Lutaml::Uml::Document] QEA document
        # @return [void]
        def verify_names(xmi_doc, qea_doc)
          # Package names verified in match_packages
          # Class names verified in match_classes
          # Additional verification could be added here
        end

        # Verify properties of matched elements
        #
        # @param xmi_doc [Lutaml::Uml::Document] XMI document
        # @param qea_doc [Lutaml::Uml::Document] QEA document
        # @return [void]
        def verify_properties(xmi_doc, qea_doc)
          # Verify class properties
          class_matches = matcher.match_classes(xmi_doc, qea_doc)
          verify_class_properties(class_matches[:matches])

          # Verify package properties
          package_matches = matcher.match_packages(xmi_doc, qea_doc)
          verify_package_properties(package_matches[:matches])
        end

        # Verify relationships (associations, generalizations)
        #
        # @param xmi_doc [Lutaml::Uml::Document] XMI document
        # @param qea_doc [Lutaml::Uml::Document] QEA document
        # @return [void]
        def verify_relationships(xmi_doc, qea_doc)
          # Verify associations are preserved
          verify_associations(xmi_doc, qea_doc)
        end

        private

        # Parse XMI file
        def parse_xmi(xmi_path)
          Lutaml::Parser.parse([File.new(xmi_path)]).first
        end

        # Parse QEA file
        def parse_qea(qea_path)
          Lutaml::Qea.parse(qea_path)
        end

        # Count all enums in document including nested
        def count_all_enums(document)
          count = document.enums&.size || 0
          count + count_enums_in_packages(document.packages)
        end

        # Count enums in packages recursively
        def count_enums_in_packages(packages)
          return 0 unless packages

          count = 0
          packages.each do |package|
            count += package.enums&.size || 0
            count += count_enums_in_packages(package.packages)
          end
          count
        end

        # Count all data types in document including nested
        def count_all_data_types(document)
          count = document.data_types&.size || 0
          count + count_data_types_in_packages(document.packages)
        end

        # Count data types in packages recursively
        def count_data_types_in_packages(packages)
          return 0 unless packages

          count = 0
          packages.each do |package|
            count += package.data_types&.size || 0
            count += count_data_types_in_packages(package.packages)
          end
          count
        end

        # Count all associations in document including nested
        def count_all_associations(document)
          count = document.associations&.size || 0
          count + count_associations_in_classes(document.classes)
          count + count_associations_in_packages(document.packages)
        end

        # Count associations in classes
        def count_associations_in_classes(classes)
          return 0 unless classes

          count = 0
          classes.each do |klass|
            count += klass.associations&.size || 0
          end
          count
        end

        # Count associations in packages recursively
        def count_associations_in_packages(packages)
          return 0 unless packages

          count = 0
          packages.each do |package|
            count += count_associations_in_classes(package.classes)
            count += count_associations_in_packages(package.packages)
          end
          count
        end

        # Verify class properties
        def verify_class_properties(matches)
          attr_count = 0
          op_count = 0

          matches.each do |qualified_name, pair|
            xmi_class = pair[:xmi]
            qea_class = pair[:qea]

            # Compare class properties
            comparison = comparator.compare_classes(xmi_class, qea_class)
            unless comparison[:equal]
              result.add_property_difference(
                :class,
                qualified_name,
                comparison[:differences],
              )
            end

            # Compare attributes
            attr_matches = matcher.match_attributes(xmi_class, qea_class)
            attr_count += attr_matches[:matches].size

            attr_matches[:matches].each do |attr_name, attr_pair|
              attr_comparison = comparator.compare_attributes(
                attr_pair[:xmi],
                attr_pair[:qea],
              )
              unless attr_comparison[:equal]
                result.add_property_difference(
                  :attribute,
                  "#{qualified_name}.#{attr_name}",
                  attr_comparison[:differences],
                )
              end
            end

            # Compare operations
            op_matches = matcher.match_operations(xmi_class, qea_class)
            op_count += op_matches[:matches].size

            op_matches[:matches].each do |op_sig, op_pair|
              op_comparison = comparator.compare_operations(
                op_pair[:xmi],
                op_pair[:qea],
              )
              unless op_comparison[:equal]
                result.add_property_difference(
                  :operation,
                  "#{qualified_name}.#{op_sig}",
                  op_comparison[:differences],
                )
              end
            end
          end

          result.add_matches(:attributes, attr_count)
          result.add_matches(:operations, op_count)
        end

        # Verify package properties
        def verify_package_properties(matches)
          matches.each do |qualified_path, pair|
            comparison = comparator.compare_packages(pair[:xmi], pair[:qea])
            unless comparison[:equal]
              result.add_property_difference(
                :package,
                qualified_path,
                comparison[:differences],
              )
            end
          end
        end

        # Verify associations
        def verify_associations(xmi_doc, qea_doc)
          # Simple count-based verification for now
          # Could be enhanced to match associations by endpoints
          xmi_assocs = count_all_associations(xmi_doc)
          qea_assocs = count_all_associations(qea_doc)

          if qea_assocs < xmi_assocs
            result.add_difference(
              "Missing #{xmi_assocs - qea_assocs} associations in QEA",
            )
          end
        end
      end
    end
  end
end
