# frozen_string_literal: true

require_relative "../validation_rule"

module Lutaml
  module Xsd
    module Validation
      module Rules
        # ElementStructureRule validates element existence and structure
        #
        # This rule checks:
        # - Element is defined in schema
        # - Element name matches schema definition
        # - Namespace is correct
        # - Provides suggestions for similar elements if not found
        #
        # Based on Jing validator element validation algorithm.
        #
        # @example Using the rule
        #   rule = ElementStructureRule.new
        #   rule.validate(xml_element, schema_element, collector)
        #
        # @see docs/JING_ALGORITHM_PORTING_GUIDE.md Element Validation
        class ElementStructureRule < ValidationRule
          # Rule category
          #
          # @return [Symbol] :structure
          def category
            :structure
          end

          # Rule description
          #
          # @return [String]
          def description
            "Validates element existence, name, and namespace correctness"
          end

          # Validate element structure
          #
          # Performs structural validation of XML elements against schema
          # definitions, including element existence, name matching, and
          # namespace validation.
          #
          # @param xml_element [XmlElement] The XML element to validate
          # @param schema_element [Lutaml::Xsd::Element, nil] The schema
          #   element definition
          # @param collector [ResultCollector] Collector for validation
          #   results
          # @return [void]
          def validate(xml_element, schema_element, collector,
                       repository: nil)
            # Step 1: Validate element declaration exists
            unless validate_element_exists(xml_element, schema_element,
                                           collector)
              return
            end

            # Step 2: Validate element name matches
            validate_element_name(xml_element, schema_element, collector)

            # Step 3: Validate namespace correctness
            validate_namespace(xml_element, schema_element, collector,
                               repository: repository)
          end

          # Structure checks run only for declarations the resolver could
          # match: unresolved names also cover refs/substitution groups the
          # resolver does not model yet, so treating them as errors here
          # would misfire. Undeclared-element detection is tracked in
          # TODO.conformance.md.
          #
          # @return [Boolean]
          def runs_without_schema?
            false
          end

          private

          # Validate element exists in schema
          #
          # @param xml_element [XmlElement] The XML element
          # @param schema_element [Lutaml::Xsd::Element, nil] Schema element
          # @param collector [ResultCollector] Result collector
          # @return [Boolean] true if element exists, false otherwise
          def validate_element_exists(xml_element, schema_element, collector)
            return true if schema_element

            report_error(
              collector,
              code: "element_not_allowed",
              message: "Element '#{xml_element.qualified_name}' is not " \
                       "allowed here",
              location: xml_element.xpath,
              context: {
                element: xml_element.qualified_name,
                namespace: xml_element.namespace_uri,
              },
              suggestion: suggest_similar_elements(xml_element),
            )

            false
          end

          # Validate element name matches schema definition
          #
          # @param xml_element [XmlElement] The XML element
          # @param schema_element [Lutaml::Xsd::Element] Schema element
          # @param collector [ResultCollector] Result collector
          # @return [void]
          def validate_element_name(xml_element, schema_element, collector)
            return if names_match?(xml_element, schema_element)

            report_error(
              collector,
              code: "element_name_mismatch",
              message: "Expected element '#{schema_element.name}', " \
                       "found '#{xml_element.name}'",
              location: xml_element.xpath,
              context: {
                expected: schema_element.name,
                actual: xml_element.name,
              },
            )
          end

          # Validate namespace matches schema definition
          #
          # @param xml_element [XmlElement] The XML element
          # @param schema_element [Lutaml::Xsd::Element] Schema element
          # @param collector [ResultCollector] Result collector
          # @return [void]
          def validate_namespace(xml_element, schema_element, collector,
                                 repository: nil)
            expected_ns = resolve_expected_namespace(schema_element, repository)
            actual_ns = xml_element.namespace_uri

            # Both nil is ok (no namespace)
            return if expected_ns.nil? && actual_ns.nil?

            # Empty string and nil are equivalent for namespace
            return if normalize_namespace(expected_ns) ==
              normalize_namespace(actual_ns)

            # A global declaration governs qualified use only — an
            # instance element in another namespace is not this
            # declaration (the content model's wildcards decide).
            return if repository&.top_level_declaration?(schema_element)

            report_error(
              collector,
              code: "namespace_mismatch",
              message: "Element '#{xml_element.name}' has incorrect " \
                       "namespace",
              location: xml_element.xpath,
              context: {
                expected_namespace: expected_ns || "(no namespace)",
                actual_namespace: actual_ns || "(no namespace)",
                element: xml_element.name,
              },
              suggestion: build_namespace_suggestion(expected_ns, actual_ns),
            )
          end

          # Check if element names match
          #
          # @param xml_element [XmlElement] The XML element
          # @param schema_element [Lutaml::Xsd::Element] Schema element
          # @return [Boolean]
          def names_match?(xml_element, schema_element)
            xml_element.name == schema_element.name
          end

          # Normalize namespace (treat empty string as nil)
          #
          # @param namespace [String, nil] Namespace URI
          # @return [String, nil]
          def normalize_namespace(namespace)
            return nil if namespace.nil? || namespace.empty?

            namespace
          end

          # Build suggestion for namespace mismatch
          #
          # @param expected [String, nil] Expected namespace
          # @param actual [String, nil] Actual namespace
          # @return [String, nil]
          def build_namespace_suggestion(expected, actual)
            if expected && !actual
              "Add namespace declaration: xmlns=\"#{expected}\""
            elsif !expected && actual
              "Remove namespace or use a different element"
            else
              "Use namespace: #{expected}"
            end
          end

          # Suggest similar elements based on fuzzy matching
          #
          # This would typically use the schema repository to find
          # similar element names. For now, returns a generic suggestion.
          #
          # @param xml_element [XmlElement] The XML element
          # @return [String, nil]
          def suggest_similar_elements(_xml_element)
            # TODO: Implement fuzzy matching against schema repository
            # For now, return generic suggestion
            "Check if element name is spelled correctly or consult " \
              "schema documentation"
          end
        end
      end
    end
  end
end
