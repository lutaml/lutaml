# frozen_string_literal: true

module Expressir
  module Commands
    # Command to import eengine comparison XML to EXPRESS Changes YAML
    class ChangesImportEengine < Base
      # Parse XML string and convert to SchemaChange
      #
      # @param xml_content [String] Eengine XML content
      # @param schema_name [String] Schema name
      # @param version [String] Version identifier
      # @param options [Hash] Additional options
      # @return [Expressir::Changes::SchemaChange]
      def self.from_xml(xml_content, schema_name, version, **)
        # Parse into CompareReport using Lutaml::Model
        compare_report = Expressir::Eengine::CompareReport.from_xml(xml_content)

        # Convert to SchemaChange
        convert_to_schema_change(compare_report, schema_name, version,
                                 xml_content: xml_content, **)
      end

      # File-based workflow (backward compatible)
      def self.call(input_file, output_file, schema_name, version, **options)
        xml_content = File.read(input_file)

        # Load existing schema if output file exists
        existing_schema = if output_file && File.exist?(output_file) && File.size(output_file).positive?
                            Expressir::Changes::SchemaChange.from_file(output_file)
                          end

        change_schema = from_xml(xml_content, schema_name, version,
                                 existing_schema: existing_schema, **options)

        if output_file
          change_schema.to_file(output_file)
          puts "Change YAML file written to: #{output_file}" if options[:verbose]
        else
          puts change_schema.to_yaml
        end

        change_schema
      end

      class << self
        private

        def convert_to_schema_change(compare_report, schema_name, version,
**options)
          # Extract changes from CompareReport
          changes = {
            additions: extract_items(compare_report.additions,
                                     options[:xml_content]),
            modifications: extract_items(compare_report.modifications,
                                         options[:xml_content]),
            deletions: extract_items(compare_report.deletions,
                                     options[:xml_content]),
          }

          # Use existing schema or create new one
          change_schema = options[:existing_schema] ||
            Expressir::Changes::SchemaChange.new(schema: schema_name)

          # No version-level description from eengine (only item-level)
          change_schema.add_or_update_version(version, nil, changes)

          change_schema
        end

        def extract_items(changes_section, xml_content)
          return [] unless changes_section&.modified_objects

          # Extract descriptions from XML as arrays
          descriptions = extract_descriptions_from_xml(xml_content)

          changes_section.modified_objects.map do |obj|
            Expressir::Changes::ItemChange.new(
              type: obj.type,
              name: obj.name,
              interfaced_items: obj.interfaced_items,
              description: descriptions[obj.name],
            )
          end
        end

        def extract_descriptions_from_xml(xml_content)
          return {} unless xml_content

          doc = Moxml::Context.new.parse(xml_content)

          doc.xpath("//modified.object").each_with_object({}) do |node, result|
            name = node["name"]
            desc_node = node.children.find do |child|
              child.is_a?(Moxml::Element) && child.name == "description"
            end
            next unless desc_node

            html = desc_node.children.map(&:to_xml).join.strip
            next if html.empty?

            result[name] = description_items(html)
          end
        end

        # The description body is XHTML-shaped (<ul><li> lists or
        # plain text); parsed as a wrapped XML fragment.
        def description_items(html)
          fragment = Moxml::Context.new.parse("<root>#{html}</root>").root
          items = fragment.xpath(".//li")
          if items.any?
            items.map { |li| li.text.strip }.reject(&:empty?)
          else
            [fragment.text.strip]
          end
        end

        def normalize_description(description)
          # Handle both String and Array (when XML has nested elements)
          case description
          when String
            description
          when Array
            # Join array elements, handling nested structures
            description.map { |elem| normalize_description(elem) }.join("\n")
          when Hash
            # Handle hash elements (from XML parsing)
            if description.key?("__text__")
              description["__text__"]
            else
              description.values.map { |v| normalize_description(v) }.join("\n")
            end
          else
            description.to_s
          end
        end

        def convert_html_to_asciidoc(text)
          # Convert <ul><li>...</li></ul> to AsciiDoc list format
          text = text.gsub(%r{<ul>\s*}i, "")
          text = text.gsub(%r{\s*</ul>}i, "")
          text = text.gsub(%r{<li>(.*?)</li>}im) do
            "* #{Regexp.last_match(1).strip}"
          end

          # Clean up any extra whitespace
          text.strip
        end
      end
    end
  end
end
