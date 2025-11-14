# frozen_string_literal: true

module Lutaml
  module Qea
    module Verification
      # Holds comparison results between XMI and QEA documents
      class ComparisonResult
        attr_reader :matches, :differences, :xmi_only, :qea_only,
                    :property_differences

        def initialize
          @matches = {
            packages: 0,
            classes: 0,
            enums: 0,
            data_types: 0,
            associations: 0,
            attributes: 0,
            operations: 0,
          }
          @differences = []
          @xmi_only = {
            packages: [],
            classes: [],
            enums: [],
            data_types: [],
            associations: [],
          }
          @qea_only = {
            packages: [],
            classes: [],
            enums: [],
            data_types: [],
            associations: [],
          }
          @property_differences = []
        end

        # Record matched elements
        #
        # @param type [Symbol] Element type (:packages, :classes, etc.)
        # @param count [Integer] Number of matches
        def add_matches(type, count)
          @matches[type] = count
        end

        # Record XMI-only elements
        #
        # @param type [Symbol] Element type
        # @param elements [Array<String>] Element names/paths
        def add_xmi_only(type, elements)
          @xmi_only[type] = elements
        end

        # Record QEA-only elements
        #
        # @param type [Symbol] Element type
        # @param elements [Array<String>] Element names/paths
        def add_qea_only(type, elements)
          @qea_only[type] = elements
        end

        # Record a difference
        #
        # @param description [String] Difference description
        def add_difference(description)
          @differences << description
        end

        # Record property-level difference
        #
        # @param element_type [Symbol] Element type
        # @param element_name [String] Element name
        # @param differences [Array<String>] List of property differences
        def add_property_difference(element_type, element_name, differences)
          @property_differences << {
            type: element_type,
            name: element_name,
            differences: differences,
          }
        end

        # Check if documents are equivalent
        # QEA is considered equivalent if it has >= information compared to XMI
        #
        # @return [Boolean] True if equivalent
        def equivalent?
          # No critical XMI-only elements (some are acceptable)
          critical_xmi_only = xmi_only[:classes].any? ||
            xmi_only[:packages].any?

          # No property differences that indicate information loss
          critical_property_diffs = property_differences.any? do |diff|
            diff[:differences].any? { |d| d.include?("QEA has fewer") }
          end

          !critical_xmi_only && !critical_property_diffs
        end

        # Generate human-readable summary
        #
        # @return [String] Summary text
        def summary
          lines = []
          lines << "=== Verification Summary ==="
          lines << ""

          # Matches
          lines << "Matched Elements:"
          matches.each do |type, count|
            next if count.zero?

            lines << "  ✓ #{type.to_s.capitalize}: #{count}"
          end
          lines << ""

          # XMI-only elements
          if xmi_only.values.any?(&:any?)
            lines << "XMI-Only Elements (missing in QEA):"
            xmi_only.each do |type, elements|
              next if elements.empty?

              lines << "  ✗ #{type.to_s.capitalize}: #{elements.size}"
              elements.first(5).each do |elem|
                lines << "    - #{elem}"
              end
              lines << "    ... and #{elements.size - 5} more" if elements.size > 5
            end
            lines << ""
          end

          # QEA-only elements (acceptable, shows QEA richness)
          if qea_only.values.any?(&:any?)
            lines << "QEA-Only Elements (additional in QEA - acceptable):"
            qea_only.each do |type, elements|
              next if elements.empty?

              lines << "  + #{type.to_s.capitalize}: #{elements.size}"
            end
            lines << ""
          end

          # Property differences
          if property_differences.any?
            lines << "Property Differences:"
            property_differences.first(10).each do |diff|
              lines << "  #{diff[:type]}: #{diff[:name]}"
              diff[:differences].each do |d|
                lines << "    - #{d}"
              end
            end
            if property_differences.size > 10
              lines << "  ... and #{property_differences.size - 10} more"
            end
            lines << ""
          end

          # Result
          lines << "Result: #{equivalent? ? '✓ EQUIVALENT' : '✗ NOT EQUIVALENT'}"
          lines << ""

          lines << if equivalent?
                     "QEA contains all XMI information (possibly more)."
                   else
                     "Information loss detected - QEA missing critical elements."
                   end

          lines.join("\n")
        end

        # Generate detailed report
        #
        # @return [Hash] Detailed report data
        def to_report
          {
            equivalent: equivalent?,
            matches: matches,
            xmi_only: xmi_only,
            qea_only: qea_only,
            property_differences: property_differences,
            summary: summary,
          }
        end

        # Generate statistics
        #
        # @return [Hash] Statistics about the comparison
        def statistics
          {
            total_matches: matches.values.sum,
            total_xmi_only: xmi_only.values.sum(&:size),
            total_qea_only: qea_only.values.sum(&:size),
            total_property_diffs: property_differences.size,
            equivalent: equivalent?,
          }
        end

        # Check if there are any issues
        #
        # @return [Boolean] True if there are issues
        def has_issues?
          !equivalent?
        end

        # Get critical issues (information loss)
        #
        # @return [Array<String>] List of critical issues
        def critical_issues
          issues = []

          # Missing packages
          if xmi_only[:packages].any?
            issues << "Missing #{xmi_only[:packages].size} packages in QEA"
          end

          # Missing classes
          if xmi_only[:classes].any?
            issues << "Missing #{xmi_only[:classes].size} classes in QEA"
          end

          # Property differences with information loss
          property_differences.each do |diff|
            diff[:differences].each do |d|
              next unless d.include?("QEA has fewer")

              issues << "#{diff[:name]}: #{d}"
            end
          end

          issues
        end

        # Get acceptable differences (QEA has more)
        #
        # @return [Array<String>] List of acceptable differences
        def acceptable_differences
          acceptable = []

          # QEA-only elements
          qea_only.each do |type, elements|
            next if elements.empty?

            acceptable << "QEA has #{elements.size} additional #{type}"
          end

          # Property differences where QEA has more
          property_differences.each do |diff|
            diff[:differences].each do |d|
              next unless d.include?("QEA has more")

              acceptable << "#{diff[:name]}: #{d}"
            end
          end

          acceptable
        end
      end
    end
  end
end
