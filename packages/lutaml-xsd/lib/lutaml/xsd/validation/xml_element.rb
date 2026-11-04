# frozen_string_literal: true

require_relative "xml_attribute"

module Lutaml
  module Xsd
    module Validation
      # XmlElement represents an XML element with validation context
      #
      # This class wraps Moxml elements to provide a consistent interface
      # for validation rules. It tracks the element's position in the
      # document tree and provides XPath information for error reporting.
      #
      # @example Create an XML element
      #   element = XmlElement.new(moxml_element, navigator)
      #
      # @example Access element properties
      #   element.name           # => "person"
      #   element.namespace_uri  # => "http://example.com"
      #   element.qualified_name # => "{http://example.com}person"
      #   element.xpath          # => "/root/person[1]"
      class XmlElement
        attr_reader :moxml_element, :navigator

        # Initialize a new XmlElement
        #
        # @param moxml_element [Moxml::Element] The underlying Moxml element
        # @param navigator [XmlNavigator] The navigator tracking context
        def initialize(moxml_element, navigator)
          @moxml_element = moxml_element
          @navigator = navigator
        end

        # Get the element's local name
        #
        # @return [String]
        def name
          @moxml_element.name
        end

        # Get the element's namespace URI
        #
        # @return [String, nil]
        def namespace_uri
          @moxml_element.namespace&.uri
        end

        # Get the element's namespace prefix
        #
        # @return [String, nil]
        def prefix
          @moxml_element.namespace&.prefix
        end

        # Get the qualified name in Clark notation
        #
        # @return [String] The qualified name in {namespace}localName format
        def qualified_name
          if namespace_uri
            "{#{namespace_uri}}#{name}"
          else
            name
          end
        end

        # Get the prefixed name
        #
        # @return [String] The prefixed name (prefix:localName) or local name
        def prefixed_name
          if prefix && !prefix.empty?
            "#{prefix}:#{name}"
          else
            name
          end
        end

        # Get all attributes of this element
        #
        # @return [Array<XmlAttribute>]
        def attributes
          return [] unless @moxml_element

          @moxml_element.attributes.map do |attr|
            XmlAttribute.new(
              attr.name,
              attr.value,
              attr.namespace&.uri,
              attr.namespace&.prefix,
            )
          end
        end

        # Get attribute by name
        #
        # @param name [String] Attribute name
        # @param namespace [String, nil] Attribute namespace
        # @return [XmlAttribute, nil]
        def attribute(name, namespace: nil)
          attributes.find do |attr|
            attr.name == name &&
              (namespace.nil? || attr.namespace_uri == namespace)
          end
        end

        # Check if element has an attribute
        #
        # @param name [String] Attribute name
        # @param namespace [String, nil] Attribute namespace
        # @return [Boolean]
        def has_attribute?(name, namespace: nil)
          !attribute(name, namespace: namespace).nil?
        end

        # Get all child elements
        #
        # @return [Array<XmlElement>]
        def children
          return [] unless @moxml_element

          @moxml_element.children.select(&:element?).map do |child|
            XmlElement.new(child, @navigator)
          end
        end

        # Get child elements by name
        #
        # @param name [String] Element name
        # @param namespace [String, nil] Element namespace
        # @return [Array<XmlElement>]
        def children_named(name, namespace: nil)
          children.select do |child|
            child.name == name &&
              (namespace.nil? || child.namespace_uri == namespace)
          end
        end

        # Get text content of the element
        #
        # Raw character data: whitespace is significant — a lone newline
        # is a value a pattern can match ([\n]). Emptiness consumers
        # strip explicitly.
        #
        # @return [String]
        def text_content
          @moxml_element.text.to_s
        end

        # Check if element has text content
        #
        # @return [Boolean]
        def has_text?
          !text_content.strip.empty?
        end

        # Check if element has child elements
        #
        # @return [Boolean]
        def has_children?
          children.any?
        end

        # Get the XPath of this element
        #
        # @return [String]
        def xpath
          @navigator.current_xpath
        end

        # Execute a block with this element in navigation context
        #
        # @yield Block to execute in element context
        # @return [Object] Result of the block
        def with_context(&)
          @navigator.with_element(self, &)
        end

        # Check if element is in a namespace
        #
        # @return [Boolean]
        def namespaced?
          !namespace_uri.nil? && !namespace_uri.empty?
        end

        # Convert to hash representation
        #
        # @return [Hash]
        def to_h
          {
            name: name,
            namespace_uri: namespace_uri,
            prefix: prefix,
            qualified_name: qualified_name,
            xpath: xpath,
            attributes: attributes.map(&:to_h),
            has_children: has_children?,
            has_text: has_text?,
          }.compact
        end

        # String representation
        #
        # @return [String]
        def to_s
          "<#{prefixed_name}>"
        end

        # Detailed string representation
        #
        # @return [String]
        def inspect
          "#<#{self.class.name} " \
            "name=#{name.inspect} " \
            "namespace_uri=#{namespace_uri.inspect} " \
            "xpath=#{xpath.inspect}>"
        end

        # Compare elements for equality
        #
        # @param other [XmlElement]
        # @return [Boolean]
        def ==(other)
          return false unless other.is_a?(XmlElement)

          name == other.name &&
            namespace_uri == other.namespace_uri &&
            xpath == other.xpath
        end

        alias eql? ==

        # Generate hash code
        #
        # @return [Integer]
        def hash
          [name, namespace_uri, xpath].hash
        end
      end
    end
  end
end
