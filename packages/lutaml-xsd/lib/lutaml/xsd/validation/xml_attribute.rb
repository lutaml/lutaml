# frozen_string_literal: true

module Lutaml
  module Xsd
    module Validation
      # XmlAttribute represents an XML attribute with validation context
      #
      # This class wraps XML attributes to provide a consistent interface
      # for validation rules. It includes the attribute name, value, and
      # namespace information needed for XSD validation.
      #
      # @example Create an XML attribute
      #   attr = XmlAttribute.new("id", "12345", "http://example.com")
      #
      # @example Access attribute properties
      #   attr.name          # => "id"
      #   attr.value         # => "12345"
      #   attr.namespace_uri # => "http://example.com"
      #   attr.qualified_name # => "{http://example.com}id"
      class XmlAttribute
        attr_reader :name, :value, :namespace_uri, :prefix

        # Initialize a new XmlAttribute
        #
        # @param name [String] The attribute name (local name without prefix)
        # @param value [String] The attribute value
        # @param namespace_uri [String, nil] The namespace URI
        # @param prefix [String, nil] The namespace prefix
        def initialize(name, value, namespace_uri = nil, prefix = nil)
          @name = name
          @value = value
          @namespace_uri = namespace_uri
          @prefix = prefix
        end

        # Get the qualified name in Clark notation
        #
        # @return [String] The qualified name in {namespace}localName format
        def qualified_name
          if @namespace_uri && !@namespace_uri.empty?
            "{#{@namespace_uri}}#{@name}"
          else
            @name
          end
        end

        # Get the prefixed name
        #
        # @return [String] The prefixed name (prefix:localName) or local name
        def prefixed_name
          if @prefix && !@prefix.empty?
            "#{@prefix}:#{@name}"
          else
            @name
          end
        end

        # Check if attribute is in a namespace
        #
        # @return [Boolean]
        def namespaced?
          !@namespace_uri.nil? && !@namespace_uri.empty?
        end

        # Convert to hash representation
        #
        # @return [Hash]
        def to_h
          {
            name: @name,
            value: @value,
            namespace_uri: @namespace_uri,
            prefix: @prefix,
            qualified_name: qualified_name,
          }.compact
        end

        # String representation
        #
        # @return [String]
        def to_s
          "#{prefixed_name}=\"#{@value}\""
        end

        # Detailed string representation
        #
        # @return [String]
        def inspect
          "#<#{self.class.name} " \
            "name=#{@name.inspect} " \
            "value=#{@value.inspect} " \
            "namespace_uri=#{@namespace_uri.inspect}>"
        end

        # Compare attributes for equality
        #
        # @param other [XmlAttribute]
        # @return [Boolean]
        def ==(other)
          return false unless other.is_a?(XmlAttribute)

          @name == other.name &&
            @value == other.value &&
            @namespace_uri == other.namespace_uri
        end

        alias eql? ==

        # Generate hash code
        #
        # @return [Integer]
        def hash
          [@name, @value, @namespace_uri].hash
        end
      end
    end
  end
end
