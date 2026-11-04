# frozen_string_literal: true

require_relative "xml_element"

module Lutaml
  module Xsd
    module Validation
      # XmlDocument represents a parsed XML document
      #
      # This class wraps the parsed Moxml document and provides
      # access to the root element and document-level operations.
      #
      # @example Create an XML document
      #   doc = XmlDocument.new(moxml_document, navigator)
      #
      # @example Access root element
      #   root = doc.root_element
      class XmlDocument
        attr_reader :moxml_document, :navigator

        # Initialize a new XmlDocument
        #
        # @param moxml_document [Moxml::Document] The parsed Moxml document
        # @param navigator [XmlNavigator] The navigator for this document
        def initialize(moxml_document, navigator)
          @moxml_document = moxml_document
          @navigator = navigator
        end

        # Get the root element of the document
        #
        # @return [XmlElement, nil]
        def root_element
          return nil unless @moxml_document.root

          XmlElement.new(@moxml_document.root, @navigator)
        end

        # Get all namespace declarations in the document
        #
        # @return [Hash<String, String>] Map of prefix to namespace URI
        def namespace_declarations
          return {} unless root_element

          collect_namespaces(root_element)
        end

        # Find elements by XPath
        #
        # @param xpath [String] XPath expression
        # @return [Array<XmlElement>]
        def xpath(xpath)
          return [] unless @moxml_document

          nodes = @moxml_document.xpath(xpath)
          nodes.select(&:element?).map do |node|
            XmlElement.new(node, @navigator)
          end
        end

        # Get the XML version
        #
        # @return [String, nil]
        def version
          @moxml_document.version
        end

        # Get the XML encoding
        #
        # @return [String, nil]
        def encoding
          @moxml_document.encoding
        end

        # Check if document is valid XML
        #
        # @return [Boolean]
        def valid_xml?
          !@moxml_document.nil? && !root_element.nil?
        end

        # Get all elements in document order
        #
        # @return [Array<XmlElement>]
        def all_elements
          return [] unless root_element

          collect_elements(root_element)
        end

        # Find elements by qualified name
        #
        # @param qualified_name [String] Qualified name in {namespace}name format
        # @return [Array<XmlElement>]
        def elements_by_qualified_name(qualified_name)
          all_elements.select { |el| el.qualified_name == qualified_name }
        end

        # Convert to hash representation
        #
        # @return [Hash]
        def to_h
          {
            version: version,
            encoding: encoding,
            root_element: root_element&.qualified_name,
            namespaces: namespace_declarations,
          }.compact
        end

        # String representation
        #
        # @return [String]
        def to_s
          "XMLDocument(root: #{root_element&.qualified_name})"
        end

        # Detailed string representation
        #
        # @return [String]
        def inspect
          "#<#{self.class.name} " \
            "root=#{root_element&.qualified_name.inspect}>"
        end

        private

        # Collect all namespace declarations recursively
        #
        # @param element [XmlElement]
        # @param namespaces [Hash]
        # @return [Hash<String, String>]
        def collect_namespaces(element, namespaces = {})
          # Add element's namespace
          if element.prefix && element.namespace_uri
            namespaces[element.prefix] =
              element.namespace_uri
          end

          # Add attribute namespaces
          element.attributes.each do |attr|
            if attr.prefix && attr.namespace_uri
              namespaces[attr.prefix] =
                attr.namespace_uri
            end
          end

          # Recurse into children
          element.children.each do |child|
            collect_namespaces(child, namespaces)
          end

          namespaces
        end

        # Collect all elements recursively
        #
        # @param element [XmlElement]
        # @param elements [Array<XmlElement>]
        # @return [Array<XmlElement>]
        def collect_elements(element, elements = [])
          elements << element

          element.children.each do |child|
            collect_elements(child, elements)
          end

          elements
        end
      end
    end
  end
end
