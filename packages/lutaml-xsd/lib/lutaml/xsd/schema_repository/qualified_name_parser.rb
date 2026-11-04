# frozen_string_literal: true

module Lutaml
  module Xsd
    class SchemaRepository
      # Internal helper for parsing qualified type names
      # Supports multiple notations:
      # - Prefixed QName: "gml:CodeType"
      # - Clark Notation: "{http://www.opengis.net/gml/3.2}CodeType"
      # - Unprefixed: "CodeType" (uses default namespace)
      class QualifiedNameParser
        # Parse a qualified name into its components
        # @param qname [String] The qualified name to parse
        # @param namespace_registry [NamespaceRegistry] Registry for prefix lookups
        # @return [Hash] Parsed components with :prefix, :namespace, :local_name
        def self.parse(qname, namespace_registry)
          return nil if qname.nil? || qname.empty?

          # Check for Clark notation: {http://...}LocalName
          if qname.start_with?("{")
            parse_clark_notation(qname)
          # Check for prefixed QName: prefix:LocalName
          elsif qname.include?(":")
            parse_prefixed_qname(qname, namespace_registry)
          # Unprefixed name - use default namespace
          else
            parse_unprefixed(qname, namespace_registry)
          end
        end

        # Parse Clark notation: {namespace}LocalName
        # @param qname [String] The Clark notation string
        # @return [Hash] Parsed components
        def self.parse_clark_notation(qname)
          match = qname.match(/^\{([^}]+)\}(.+)$/)
          return nil unless match

          {
            prefix: nil,
            namespace: match[1],
            local_name: match[2],
          }
        end

        # Parse prefixed QName: prefix:LocalName
        # @param qname [String] The prefixed QName
        # @param namespace_registry [NamespaceRegistry] Registry for prefix lookups
        # @return [Hash] Parsed components
        def self.parse_prefixed_qname(qname, namespace_registry)
          parts = qname.split(":", 2)
          return nil if parts.size != 2

          prefix = parts[0]
          local_name = parts[1]
          namespace = namespace_registry.get_uri(prefix)

          {
            prefix: prefix,
            namespace: namespace,
            local_name: local_name,
          }
        end

        # Parse unprefixed name using default namespace
        # @param qname [String] The local name
        # @param namespace_registry [NamespaceRegistry] Registry for default namespace
        # @return [Hash] Parsed components
        def self.parse_unprefixed(qname, namespace_registry)
          {
            prefix: nil,
            namespace: namespace_registry.default_namespace,
            local_name: qname,
          }
        end

        # Convert parsed components back to Clark notation
        # @param parsed [Hash] Parsed components with :namespace and :local_name
        # @return [String] Clark notation string
        def self.to_clark_notation(parsed)
          return nil unless parsed && parsed[:local_name]

          if parsed[:namespace]
            "{#{parsed[:namespace]}}#{parsed[:local_name]}"
          else
            parsed[:local_name]
          end
        end
      end
    end
  end
end
