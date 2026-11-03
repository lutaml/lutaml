# frozen_string_literal: true

require "moxml"

module Lutaml
  module Xsd
    module Validation
      # SchemaLocationHints extracts the schema documents an instance
      # names in xsi:schemaLocation / xsi:noNamespaceSchemaLocation
      # (root element only), resolved against a base directory.
      #
      # Hints are followed ONLY when the caller provides the base —
      # relative locations never resolve against the process working
      # directory implicitly.
      module SchemaLocationHints
        XSI_NAMESPACE = "http://www.w3.org/2001/XMLSchema-instance"

        # @param xml_content [String] the instance document
        # @param base_dir [String] directory the locations resolve from
        # @return [Array<String>] existing schema file paths
        def self.paths(xml_content, base_dir)
          root = Moxml::Context.new.parse(xml_content).root
          return [] unless root

          locations = []
          root.attributes.each do |attribute|
            next unless attribute.namespace&.uri == XSI_NAMESPACE

            case attribute.name
            when "schemaLocation"
              attribute.value.to_s.split(/\s+/).each_slice(2) do |_ns, location|
                next if location.nil? || location.empty?

                path = File.expand_path(location, base_dir)
                locations << path if File.exist?(path)
              end
            when "noNamespaceSchemaLocation"
              path = File.expand_path(attribute.value.to_s, base_dir)
              locations << path if File.exist?(path)
            end
          end
          locations
        rescue StandardError
          []
        end
      end
    end
  end
end
