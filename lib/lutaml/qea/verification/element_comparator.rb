# frozen_string_literal: true

module Lutaml
  module Qea
    module Verification
      # Compares matched element pairs to find differences
      class ElementComparator
        # Compare package properties
        #
        # @param xmi_pkg [Lutaml::Uml::Package] XMI package
        # @param qea_pkg [Lutaml::Uml::Package] QEA package
        # @return [Hash] Comparison result with :equal and :differences
        def compare_packages(xmi_pkg, qea_pkg) # rubocop:disable Metrics/AbcSize,Metrics/MethodLength
          differences = []

          # Compare basic properties
          unless names_equal?(xmi_pkg.name, qea_pkg.name)
            differences << "Name: '#{xmi_pkg.name}' vs '#{qea_pkg.name}'"
          end

          # Compare collection counts
          compare_collection_count(
            xmi_pkg.classes, qea_pkg.classes, "classes", differences
          )
          compare_collection_count(
            xmi_pkg.enums, qea_pkg.enums, "enums", differences
          )
          compare_collection_count(
            xmi_pkg.data_types, qea_pkg.data_types, "data_types", differences
          )
          compare_collection_count(
            xmi_pkg.packages, qea_pkg.packages, "packages", differences
          )

          {
            equal: differences.empty?,
            differences: differences,
          }
        end

        # Compare class properties
        #
        # @param xmi_class [Lutaml::Uml::Class] XMI class
        # @param qea_class [Lutaml::Uml::Class] QEA class
        # @return [Hash] Comparison result with :equal and :differences
        def compare_classes(xmi_class, qea_class) # rubocop:disable Metrics/AbcSize,Metrics/CyclomaticComplexity,Metrics/MethodLength,Metrics/PerceivedComplexity
          differences = []

          # Compare name
          unless names_equal?(xmi_class.name, qea_class.name)
            differences << "Name: '#{xmi_class.name}' vs '#{qea_class.name}'"
          end

          # Compare is_abstract
          if xmi_class.respond_to?(:is_abstract) &&
              qea_class.respond_to?(:is_abstract) &&
              xmi_class.is_abstract != qea_class.is_abstract
            differences << "is_abstract: #{xmi_class.is_abstract} " \
                           "vs #{qea_class.is_abstract}"
          end

          # Compare type
          if xmi_class.respond_to?(:type) &&
              qea_class.respond_to?(:type) &&
              normalize_value(xmi_class.type) != normalize_value(qea_class.type)
            differences << "type: '#{xmi_class.type}' vs '#{qea_class.type}'"
          end

          # Compare modifier
          if xmi_class.respond_to?(:modifier) &&
              qea_class.respond_to?(:modifier) &&
              normalize_value(xmi_class.modifier) !=
                  normalize_value(qea_class.modifier)
            differences << "modifier: '#{xmi_class.modifier}' " \
                           "vs '#{qea_class.modifier}'"
          end

          # Compare collection counts
          compare_collection_count(
            xmi_class.attributes, qea_class.attributes,
            "attributes", differences
          )
          compare_collection_count(
            xmi_class.operations, qea_class.operations,
            "operations", differences
          )

          {
            equal: differences.empty?,
            differences: differences,
          }
        end

        # Compare attribute properties
        #
        # @param xmi_attr [Lutaml::Uml::TopElementAttribute] XMI attribute
        # @param qea_attr [Lutaml::Uml::TopElementAttribute] QEA attribute
        # @return [Hash] Comparison result with :equal and :differences
        def compare_attributes(xmi_attr, qea_attr) # rubocop:disable Metrics/AbcSize,Metrics/CyclomaticComplexity,Metrics/MethodLength,Metrics/PerceivedComplexity
          differences = []

          # Compare name
          unless names_equal?(xmi_attr.name, qea_attr.name)
            differences << "Name: '#{xmi_attr.name}' vs '#{qea_attr.name}'"
          end

          # Compare type
          if xmi_attr.respond_to?(:type) &&
              qea_attr.respond_to?(:type) &&
              normalize_value(xmi_attr.type) !=
                  normalize_value(qea_attr.type)
            differences << "type: '#{xmi_attr.type}' vs '#{qea_attr.type}'"
          end

          # Compare visibility
          if xmi_attr.respond_to?(:visibility) &&
              qea_attr.respond_to?(:visibility) &&
              normalize_value(xmi_attr.visibility) !=
                  normalize_value(qea_attr.visibility)
            differences << "visibility: '#{xmi_attr.visibility}' " \
                           "vs '#{qea_attr.visibility}'"
          end

          # Compare cardinality if present
          if xmi_attr.respond_to?(:cardinality) &&
              qea_attr.respond_to?(:cardinality)
            xmi_card = xmi_attr.cardinality
            qea_card = qea_attr.cardinality
            if xmi_card && qea_card
              unless cardinalities_equal?(xmi_card, qea_card)
                differences << "cardinality: #{format_cardinality(xmi_card)} " \
                               "vs #{format_cardinality(qea_card)}"
              end
            elsif xmi_card || qea_card
              differences << "cardinality: #{format_cardinality(xmi_card)} " \
                             "vs #{format_cardinality(qea_card)}"
            end
          end

          {
            equal: differences.empty?,
            differences: differences,
          }
        end

        # Compare operation properties
        #
        # @param xmi_op [Lutaml::Uml::Operation] XMI operation
        # @param qea_op [Lutaml::Uml::Operation] QEA operation
        # @return [Hash] Comparison result with :equal and :differences
        def compare_operations(xmi_op, qea_op) # rubocop:disable Metrics/AbcSize,Metrics/CyclomaticComplexity,Metrics/MethodLength,Metrics/PerceivedComplexity
          differences = []

          # Compare name
          unless names_equal?(xmi_op.name, qea_op.name)
            differences << "Name: '#{xmi_op.name}' vs '#{qea_op.name}'"
          end

          # Compare return type
          if xmi_op.respond_to?(:return_type) &&
              qea_op.respond_to?(:return_type) &&
              normalize_value(xmi_op.return_type) !=
                  normalize_value(qea_op.return_type)
            differences << "return_type: '#{xmi_op.return_type}' " \
                           "vs '#{qea_op.return_type}'"
          end

          # Compare visibility
          if xmi_op.respond_to?(:visibility) &&
              qea_op.respond_to?(:visibility) &&
              normalize_value(xmi_op.visibility) !=
                  normalize_value(qea_op.visibility)
            differences << "visibility: '#{xmi_op.visibility}' " \
                           "vs '#{qea_op.visibility}'"
          end

          # Compare parameter counts
          compare_collection_count(
            xmi_op.parameters, qea_op.parameters, "parameters", differences
          )

          {
            equal: differences.empty?,
            differences: differences,
          }
        end

        # Compare association properties
        #
        # @param xmi_assoc [Lutaml::Uml::Association] XMI association
        # @param qea_assoc [Lutaml::Uml::Association] QEA association
        # @return [Hash] Comparison result with :equal and :differences
        def compare_associations(xmi_assoc, qea_assoc) # rubocop:disable Metrics/AbcSize,Metrics/CyclomaticComplexity,Metrics/MethodLength,Metrics/PerceivedComplexity
          differences = []

          # Compare owner end
          unless normalize_value(xmi_assoc.owner_end) ==
              normalize_value(qea_assoc.owner_end)
            differences << "owner_end: '#{xmi_assoc.owner_end}' " \
                           "vs '#{qea_assoc.owner_end}'"
          end

          # Compare member end
          unless normalize_value(xmi_assoc.member_end) ==
              normalize_value(qea_assoc.member_end)
            differences << "member_end: '#{xmi_assoc.member_end}' " \
                           "vs '#{qea_assoc.member_end}'"
          end

          # Compare owner end cardinality
          if xmi_assoc.owner_end_cardinality &&
              qea_assoc.owner_end_cardinality &&
              !cardinalities_equal?(
                xmi_assoc.owner_end_cardinality,
                qea_assoc.owner_end_cardinality,
              )
            differences << "owner_end_cardinality: " \
                           "#{format_cardinality(xmi_assoc
                           .owner_end_cardinality)} " \
                           "vs #{format_cardinality(qea_assoc
                           .owner_end_cardinality)}"
          end

          # Compare member end cardinality
          if xmi_assoc.member_end_cardinality &&
              qea_assoc.member_end_cardinality &&
              !cardinalities_equal?(
                xmi_assoc.member_end_cardinality,
                qea_assoc.member_end_cardinality,
              )
            differences << "member_end_cardinality: " \
                           "#{format_cardinality(xmi_assoc
                            .member_end_cardinality)} " \
                            "vs #{format_cardinality(qea_assoc
                            .member_end_cardinality)}"
          end

          {
            equal: differences.empty?,
            differences: differences,
          }
        end

        private

        # Compare names with normalization
        def names_equal?(name1, name2)
          normalize_value(name1) == normalize_value(name2)
        end

        # Normalize value for comparison
        def normalize_value(value)
          return nil if value.nil?
          return value unless value.is_a?(String)

          value.strip
        end

        # Compare collection counts
        def compare_collection_count(xmi_coll, qea_coll, name, differences) # rubocop:disable Metrics/CyclomaticComplexity,Metrics/MethodLength,Metrics/PerceivedComplexity
          xmi_count = xmi_coll&.size || 0
          qea_count = qea_coll&.size || 0

          return if xmi_count == qea_count

          suffix = if qea_count < xmi_count
                     "QEA has fewer"
                   else
                     "QEA has more (acceptable)"
                   end
          differences << "#{name}: #{xmi_count} (XMI) vs " \
                         "#{qea_count} (QEA) - #{suffix}"
        end

        # Check if cardinalities are equal
        def cardinalities_equal?(card1, card2) # rubocop:disable Metrics/AbcSize,Metrics/CyclomaticComplexity,Metrics/MethodLength,Metrics/PerceivedComplexity
          return true if card1.nil? && card2.nil?
          return false if card1.nil? || card2.nil?

          min_equal = (
            card1.min || (card1.respond_to?(:min_value) && card1.min_value)
          ) == (
            card2.min || (card2.respond_to?(:min_value) && card2.min_value)
          )
          max_equal = (
            card1.max || (card1.respond_to?(:max_value) && card1.max_value)
          ) == (
            card2.max || (card2.respond_to?(:max_value) && card2.max_value)
          )

          min_equal && max_equal
        end

        # Format cardinality for display
        def format_cardinality(card)
          return "nil" if card.nil?

          min = card.min || (card.respond_to?(:min_value) && card.min_value)
          max = card.max || (card.respond_to?(:max_value) && card.max_value)

          "#{min}..#{max}"
        end
      end
    end
  end
end
