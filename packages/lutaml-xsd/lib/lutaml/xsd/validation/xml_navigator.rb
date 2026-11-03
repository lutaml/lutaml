# frozen_string_literal: true

require "moxml"
require_relative "xml_document"
require_relative "xml_element"

module Lutaml
  module Xsd
    module Validation
      # XmlNavigator wraps Moxml for XML navigation with XPath tracking
      #
      # This class provides a consistent interface for navigating XML documents
      # while maintaining context for validation. It tracks the current position
      # in the document tree and provides XPath information for error reporting.
      #
      # @example Parse and navigate XML
      #   navigator = XmlNavigator.new(xml_content)
      #   root = navigator.root_element
      #   navigator.with_element(root) do
      #     puts navigator.current_xpath  # => "/root"
      #   end
      #
      # @example Access the document
      #   doc = navigator.document
      #   elements = doc.all_elements
      class XmlNavigator
        attr_reader :moxml_document, :current_path

        # Initialize a new XmlNavigator
        #
        # @param xml_content [String] The XML content to parse
        # @param adapter [Symbol] The Moxml adapter to use (defaults to Moxml default)
        #
        # @raise [ArgumentError] if xml_content is nil or empty
        # @raise [Moxml::ParseError] if XML parsing fails
        def initialize(xml_content, adapter: nil)
          raise ArgumentError, "XML content cannot be nil" if xml_content.nil?

          if xml_content.empty?
            raise ArgumentError,
                  "XML content cannot be empty"
          end

          @moxml_document = parse_xml(xml_content, adapter)
          @current_path = []
        end

        # Get the XML document
        #
        # @return [XmlDocument]
        def document
          @document ||= XmlDocument.new(@moxml_document, self)
        end

        # Get the root element
        #
        # @return [XmlElement, nil]
        def root_element
          document.root_element
        end

        # Get the current XPath location
        #
        # Returns the XPath of the current position in the document tree
        # based on the navigation context.
        #
        # @return [String] XPath string (e.g., "/root/child[1]")
        def current_xpath
          return "/" if @current_path.empty?

          "/" + @current_path.map.with_index do |segment, idx|
            format_xpath_segment(segment, idx)
          end.join("/")
        end

        # Execute a block within an element's context
        #
        # This method maintains the navigation path stack, adding the element
        # to the path before executing the block and removing it afterwards.
        #
        # @param element [XmlElement] The element to navigate into
        # @yield Block to execute within element context
        # @return [Object] Result of the block
        #
        # @example Navigate into an element
        #   navigator.with_element(child_element) do
        #     # Current XPath is updated to include child_element
        #     navigator.validate_element
        #   end
        def with_element(element)
          @current_path.push(build_path_segment(element))
          yield
        ensure
          @current_path.pop
        end

        # Navigate to a specific element by index
        #
        # @param element [XmlElement] The element to navigate to
        # @param index [Integer] The index of this element among siblings
        # @yield Block to execute within element context
        # @return [Object] Result of the block
        def with_indexed_element(element, index)
          segment = build_path_segment(element, index)
          @current_path.push(segment)
          yield
        ensure
          @current_path.pop
        end

        # Get the depth of the current position
        #
        # @return [Integer] The depth (0 for root, 1 for immediate children, etc.)
        def depth
          @current_path.length
        end

        # Check if currently at root
        #
        # @return [Boolean]
        def at_root?
          @current_path.empty?
        end

        # Get the parent XPath
        #
        # @return [String, nil] Parent XPath or nil if at root
        def parent_xpath
          return nil if @current_path.length <= 1

          "/" + @current_path[0..-2].map.with_index do |segment, idx|
            format_xpath_segment(segment, idx)
          end.join("/")
        end

        # Reset navigation to root
        #
        # @return [void]
        def reset
          @current_path.clear
        end

        # Find elements by XPath expression
        #
        # @param xpath_expr [String] XPath expression
        # @return [Array<XmlElement>]
        def xpath(xpath_expr)
          document.xpath(xpath_expr)
        end

        # Convert to string representation
        #
        # @return [String]
        def to_s
          "XmlNavigator(xpath: #{current_xpath})"
        end

        # Detailed string representation
        #
        # @return [String]
        def inspect
          "#<#{self.class.name} " \
            "current_xpath=#{current_xpath.inspect} " \
            "depth=#{depth}>"
        end

        private

        # Parse XML content using Moxml
        #
        # @param content [String] XML content
        # @param adapter [Symbol] Moxml adapter
        # @return [Moxml::Document]
        # @raise [Moxml::ParseError] if parsing fails
        def parse_xml(content, adapter)
          Moxml::Context.new(adapter).parse(content)
        rescue Moxml::ParseError
          raise
        rescue StandardError => e
          raise Moxml::ParseError, "Failed to parse XML: #{e.message}"
        end

        # Build a path segment for an element
        #
        # @param element [XmlElement] The element
        # @param index [Integer, nil] Optional index
        # @return [Hash] Path segment with element info
        def build_path_segment(element, index = nil)
          {
            name: element.name,
            namespace_uri: element.namespace_uri,
            prefix: element.prefix,
            index: index,
          }
        end

        # Format a path segment as XPath
        #
        # @param segment [Hash] The path segment
        # @param position [Integer] Position in path
        # @return [String] Formatted XPath segment
        def format_xpath_segment(segment, _position)
          name = if segment[:prefix] && !segment[:prefix].empty?
                   "#{segment[:prefix]}:#{segment[:name]}"
                 else
                   segment[:name]
                 end

          if segment[:index]
            "#{name}[#{segment[:index]}]"
          else
            # Calculate index among siblings with same name
            name
          end
        end
      end
    end
  end
end

# Define ParseError if not defined by Moxml
module Moxml
  class ParseError < StandardError; end unless defined?(ParseError)
end
