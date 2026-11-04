# frozen_string_literal: true

require_relative "../validation_rule"

module Lutaml
  module Xsd
    module Validation
      module Rules
        # IdUniquenessRule enforces built-in xs:ID uniqueness
        #
        # XSD 1.0 §3.3.3: the value of an ID-typed element or attribute
        # must be unique within the document (elemZ016: two ID elements
        # carrying the same value are invalid). The rule keeps a
        # per-job registry of values — the registry instance is fresh
        # per validation — and reports a value's second and later
        # appearances.
        class IdUniquenessRule < ValidationRule
          def category
            :identity
          end

          def description
            "Validates built-in xs:ID value uniqueness within the document"
          end

          def validate(xml_element, schema_element, collector,
                       repository: nil)
            return unless repository
            return unless
              schema_element.is_a?(Lutaml::Xml::Schema::Xsd::Element)

            # The walk invokes the rule per element and per category;
            # the document is scanned exactly once, from the first
            # (root) invocation — element wrappers are not
            # identity-stable across passes.
            return if @scanned

            @scanned = true
            scan_ids(xml_element, schema_element, collector, repository)
          end

          private

          # Depth-first scan recording every ID-typed value.
          #
          # @return [void]
          def scan_ids(element, declaration, collector, repository)
            record_id(
              element_id_value(element, declaration, repository),
              element, collector, "element '#{element.name}'"
            )

            attribute_id_declarations(declaration, repository).each do |attr|
              instance = element.attributes.find do |candidate|
                candidate.name == attr.name
              end
              next unless instance

              record_id(instance.value, element, collector,
                        "attribute '#{attr.name}'")
            end

            element.children.each do |child|
              child_declaration = repository.resolve(
                child.name, child.namespace_uri
              )
              next unless child_declaration

              scan_ids(child, child_declaration, collector, repository)
            end
          end

          # The element's text content when its declaration is ID-typed.
          #
          # @return [String, nil]
          def element_id_value(xml_element, schema_element, repository)
            return nil unless id_typed?(schema_element, repository)

            text = xml_element.text_content.to_s
            text.strip.empty? ? nil : text
          end

          # Whether the declaration's type is xs:ID — a direct builtin
          # reference or an inline restriction of it.
          #
          # @return [Boolean]
          def id_typed?(declaration, _repository)
            id_type_reference?(declaration.type.to_s) ||
              id_type_reference?(
                declaration.simple_type&.restriction&.base.to_s,
              )
          end

          # @return [Boolean]
          def id_type_reference?(reference)
            parts = reference.split(":")
            parts.size == 2 && %w[xs xsd].include?(parts.first) &&
              parts.last == "ID"
          end

          # The declaration's own attribute particles typed xs:ID:
          # direct attributes, refs resolved to their declarations, and
          # attributeGroup members.
          #
          # @return [Array<Lutaml::Xml::Schema::Xsd::Attribute>]
          def attribute_id_declarations(schema_element, repository)
            type = schema_element.complex_type ||
              repository.resolve_type(schema_element)
            return [] unless type.is_a?(Lutaml::Xml::Schema::Xsd::ComplexType)

            particles = Array(type.attribute)
            Array(type.attribute_group).each do |group|
              declaration = repository.resolve_attribute_group(
                (group.ref || group.name).to_s.split(":").last,
              )
              particles.concat(Array(declaration&.attribute))
            end

            particles.filter_map do |particle|
              resolved = particle
              unless particle.ref.to_s.empty?
                resolved = repository.resolve_attribute(
                  particle.ref.split(":").last, nil
                )
              end
              next nil unless resolved && id_typed?(resolved, repository)

              resolved
            end
          end

          # Report the value's second and later appearances from a
          # different node or subject (a single scan runs per
          # document).
          #
          # @return [void]
          def record_id(value, xml_element, collector, subject)
            return if value.nil? || value.to_s.empty?

            @seen_ids ||= {}

            first = @seen_ids[value]
            unless first
              @seen_ids[value] = [xml_element.xpath, subject]
              return
            end
            first_xpath, = first

            report_error(
              collector,
              code: "id_duplicate_violation",
              message: "#{subject} has ID value '#{value}' that is " \
                       "already used at #{first_xpath}",
              location: xml_element.xpath,
              context: { value: value, first: first_xpath },
            )
          end
        end
      end
    end
  end
end
