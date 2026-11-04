# frozen_string_literal: true

module Expressir
  module Eengine
    # Represents an Eengine comparison XML report
    # Supports three modes: ARM, MIM, and Schema
    class CompareReport < Lutaml::Model::Serializable
      attribute :modifications, ChangesSection
      attribute :additions, ChangesSection
      attribute :deletions, ChangesSection

      xml do
        element "schema.changes"
        map_element "schema.modifications", to: :modifications
        map_element "schema.additions", to: :additions
        map_element "schema.deletions", to: :deletions
      end

      class << self
        # Parse XML and return appropriate report class based on mode
        #
        # @param xml_content [String] XML content
        # @return [CompareReport, ArmCompareReport, MimCompareReport]
        def from_xml(xml_content)
          mode = detect_mode(xml_content)

          case mode
          when "arm"
            ArmCompareReport.from_xml(xml_content)
          when "mim"
            MimCompareReport.from_xml(xml_content)
          else
            super
          end
        end

        # Load a CompareReport from an XML file
        #
        # @param path [String] Path to the XML file
        # @return [CompareReport] The loaded comparison report
        def from_file(path)
          from_xml(File.read(path))
        end

        private

        # Detect XML mode from content
        #
        # @param xml_content [String] XML content
        # @return [String] "arm", "mim", or "schema"
        def detect_mode(xml_content)
          if xml_content.include?("<arm.changes")
            "arm"
          elsif xml_content.include?("<mim.changes")
            "mim"
          else
            "schema"
          end
        end
      end

      # Detect XML mode from the report
      # @return [String] "arm", "mim", or "schema"
      def mode
        "schema"
      end
    end
  end
end
