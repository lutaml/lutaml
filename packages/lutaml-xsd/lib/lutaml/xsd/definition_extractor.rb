# frozen_string_literal: true

require "moxml"

module Lutaml
  module Xsd
    # Extracts XSD definitions from schema files
    # Shows actual XSD source code for types, elements, and attributes
    class DefinitionExtractor
      attr_reader :package

      # @param package [SchemaRepositoryPackage] Package to extract from
      def initialize(package)
        @package = package
      end

      # Extract type definition
      # @param qname [String] Qualified name (e.g., "gml:PointType" or "PointType")
      # @return [Hash, nil] Definition info or nil
      def extract_type_definition(qname)
        repository = package.load_repository
        type_result = find_type_in_repository(repository, qname)
        return nil unless type_result

        schema, type_obj, schema_file = type_result

        extract_definition_from_xsd(
          schema_file,
          type_obj.name,
          type_obj.class.name.split("::").last.downcase,
        ).tap do |def_info|
          if def_info
            def_info[:qname] = qname
            def_info[:namespace] = schema.target_namespace
            def_info[:category] = type_obj.class.name.split("::").last
            def_info[:type_object] = type_obj
            def_info[:schema] = schema
          end
        end
      end

      # Extract element definition
      # @param qname [String] Qualified name
      # @return [Hash, nil] Definition info or nil
      def extract_element_definition(qname)
        repository = package.load_repository
        element_result = find_element_in_repository(repository, qname)
        return nil unless element_result

        schema, element_obj, schema_file = element_result

        extract_definition_from_xsd(
          schema_file,
          element_obj.name,
          "element",
        ).tap do |def_info|
          if def_info
            def_info[:qname] = qname
            def_info[:namespace] = schema.target_namespace
            def_info[:category] = "Element"
            def_info[:element_object] = element_obj
            def_info[:schema] = schema
          end
        end
      end

      # Extract attribute definition
      # @param qname [String] Qualified name (may include @ prefix)
      # @return [Hash, nil] Definition info or nil
      def extract_attribute_definition(qname)
        repository = package.load_repository
        # Remove @ prefix if present
        clean_name = qname.sub(/^@/, "")

        attribute_result = find_attribute_in_repository(repository, clean_name)
        return nil unless attribute_result

        schema, attr_obj, schema_file = attribute_result

        extract_definition_from_xsd(
          schema_file,
          attr_obj.name,
          "attribute",
        ).tap do |def_info|
          if def_info
            def_info[:qname] = clean_name
            def_info[:namespace] = schema.target_namespace
            def_info[:category] = "Attribute"
            def_info[:attribute_object] = attr_obj
            def_info[:schema] = schema
          end
        end
      end

      private

      # Find type in repository
      # @param repository [SchemaRepository] Repository to search
      # @param qname [String] Qualified name
      # @return [Array, nil] [schema, type, schema_file] or nil
      def find_type_in_repository(repository, qname)
        namespace, local_name = parse_qname(repository, qname)

        Lutaml::Xml::Schema::Xsd::Schema.processed_schemas.each do |schema_file, schema|
          next unless namespace.nil? || schema.target_namespace == namespace

          # Check complex types
          type_obj = schema.complex_type.find { |t| t.name == local_name }
          return [schema, type_obj, schema_file] if type_obj

          # Check simple types
          type_obj = schema.simple_type.find { |t| t.name == local_name }
          return [schema, type_obj, schema_file] if type_obj
        end

        nil
      end

      # Find element in repository
      # @param repository [SchemaRepository] Repository to search
      # @param qname [String] Qualified name
      # @return [Array, nil] [schema, element, schema_file] or nil
      def find_element_in_repository(repository, qname)
        namespace, local_name = parse_qname(repository, qname)

        Lutaml::Xml::Schema::Xsd::Schema.processed_schemas.each do |schema_file, schema|
          next unless namespace.nil? || schema.target_namespace == namespace

          element_obj = schema.element.find { |e| e.name == local_name }
          return [schema, element_obj, schema_file] if element_obj
        end

        nil
      end

      # Find attribute in repository
      # @param repository [SchemaRepository] Repository to search
      # @param qname [String] Qualified name
      # @return [Array, nil] [schema, attribute, schema_file] or nil
      def find_attribute_in_repository(repository, qname)
        namespace, local_name = parse_qname(repository, qname)

        Lutaml::Xml::Schema::Xsd::Schema.processed_schemas.each do |schema_file, schema|
          next unless namespace.nil? || schema.target_namespace == namespace

          attr_obj = schema.attribute.find { |a| a.name == local_name }
          return [schema, attr_obj, schema_file] if attr_obj
        end

        nil
      end

      # Parse qualified name into namespace and local name
      # @param repository [SchemaRepository] Repository for namespace lookup
      # @param qname [String] Qualified name (e.g., "gml:PointType")
      # @return [Array] [namespace_uri, local_name]
      def parse_qname(repository, qname)
        if qname.include?(":")
          prefix, local = qname.split(":", 2)
          namespace = find_namespace_by_prefix(repository, prefix)
          [namespace, local]
        else
          [nil, qname]
        end
      end

      # Find namespace URI by prefix
      # @param repository [SchemaRepository] Repository with mappings
      # @param prefix [String] Namespace prefix
      # @return [String, nil] Namespace URI or nil
      def find_namespace_by_prefix(repository, prefix)
        mappings = repository.namespace_mappings || []
        mapping = mappings.find { |m| m.prefix == prefix }
        mapping&.uri
      end

      # Extract definition from XSD file
      # @param schema_file [String] Path to XSD file
      # @param name [String] Element/type/attribute name
      # @param type [String] Type of definition (element, complextype, simpletype, attribute)
      # @return [Hash, nil] Definition info with :file, :line, :xsd_source
      def extract_definition_from_xsd(schema_file, name, type)
        return nil unless File.exist?(schema_file)

        content = File.read(schema_file)
        doc = Moxml::Context.new.parse(content)

        # Find the definition node
        definition_node = find_definition_node(doc, name, type)
        return nil unless definition_node

        # Extract line number (approximate)
        line_number = estimate_line_number(content, name, type)

        # Extract XSD source for this node
        xsd_source = extract_node_xml(definition_node)

        {
          file: File.basename(schema_file),
          full_path: schema_file,
          line: line_number,
          xsd_source: xsd_source,
        }
      end

      # Find definition node in XML document
      # @param node [Moxml::Document] XML document to search
      # @param name [String] Name to find
      # @param type [String] Type of definition
      # @return [Moxml::Element, nil] Found node or nil
      def find_definition_node(node, name, type)
        # Use XPath to find the definition
        xpath = case type.downcase
                when "complextype"
                  "//xs:complexType[@name='#{name}'] | //*[local-name()='complexType'][@name='#{name}']"
                when "simpletype"
                  "//xs:simpleType[@name='#{name}'] | //*[local-name()='simpleType'][@name='#{name}']"
                when "element"
                  "//xs:element[@name='#{name}'] | //*[local-name()='element'][@name='#{name}']"
                when "attribute"
                  "//xs:attribute[@name='#{name}'] | //*[local-name()='attribute'][@name='#{name}']"
                else
                  "//*[@name='#{name}']"
                end

        node.xpath(xpath).first
      end

      # Extract XML from node as string
      # @param node [Moxml::Element] XML node
      # @return [String] XML string
      def extract_node_xml(node)
        node.to_xml
      rescue StandardError
        "<Could not extract XSD source>"
      end

      # Estimate line number in file
      # @param content [String] File content
      # @param name [String] Name to search for
      # @param type [String] Type of definition
      # @return [Integer] Estimated line number
      def estimate_line_number(content, name, type)
        # Look for the definition line
        pattern = case type.downcase
                  when "complextype"
                    /<xs:complexType\s+name="#{Regexp.escape(name)}"/i
                  when "simpletype"
                    /<xs:simpleType\s+name="#{Regexp.escape(name)}"/i
                  when "element"
                    /<xs:element\s+name="#{Regexp.escape(name)}"/i
                  when "attribute"
                    /<xs:attribute\s+name="#{Regexp.escape(name)}"/i
                  else
                    /name="#{Regexp.escape(name)}"/
                  end

        content.lines.each_with_index do |line, idx|
          return idx + 1 if line.match?(pattern)
        end

        1 # Default to line 1 if not found
      end
    end
  end
end
