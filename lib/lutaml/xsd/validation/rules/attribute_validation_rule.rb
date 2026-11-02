# frozen_string_literal: true

require_relative "../validation_rule"
require_relative "../xsd_regex"

module Lutaml
  module Xsd
    module Validation
      module Rules
        # AttributeValidationRule validates element attributes
        #
        # This rule checks:
        # - Required attributes are present
        # - Attribute values match schema definitions
        # - No unexpected attributes exist
        # - Attribute types are valid
        #
        # Based on Jing validator attribute validation algorithm.
        #
        # @example Using the rule
        #   rule = AttributeValidationRule.new
        #   rule.validate(xml_element, schema_element, collector)
        #
        # @see docs/JING_ALGORITHM_PORTING_GUIDE.md Attribute Validation
        class AttributeValidationRule < ValidationRule
          include EngineBacked
          include ValueSpace

          PROBE_SCHEMA = <<~XSD
            <xs:schema xmlns:xs="http://www.w3.org/2001/XMLSchema">
              <xs:complexType name="probe">
                <xs:anyAttribute namespace="##local"/>
              </xs:complexType>
            </xs:schema>
          XSD

          CONTENT_KINDS = %i[complex_content simple_content].freeze
          CONTENT_PART_KINDS = %i[extension restriction].freeze

          # length/minLength/maxLength are forbidden on QName and
          # NOTATION and every type derived from them (XSD 1.0
          # §4.3.1.2): a restriction carrying them is ignored there.
          FORBIDDEN_LENGTH_BASES = %w[QName NOTATION].freeze
          FORBIDDEN_LENGTH_DEPTH_LIMIT = 8

          # Rule category
          #
          # @return [Symbol] :constraint
          def category
            :constraint
          end

          # Rule description
          #
          # @return [String]
          def description
            "Validates element attributes against schema definitions"
          end

          # Validate element attributes
          #
          # Validates all attributes of an XML element against the schema
          # definition, checking presence of required attributes, validity
          # of values, and absence of unexpected attributes.
          #
          # @param xml_element [XmlElement] The XML element to validate
          # @param schema_element [Lutaml::Xsd::Element, Lutaml::Xsd::ComplexType]
          #   The schema definition
          # @param collector [ResultCollector] Collector for validation results
          # @return [void]
          def validate(xml_element, schema_element, collector,
                       repository: nil)
            return unless schema_element

            # An element whose type is xs:anyType — declared, defaulted
            # (no type at all), or overridden — accepts any attributes.
            return if any_type_attributes?(xml_element, schema_element)

            schema_attributes =
              collect_schema_attributes(schema_element, repository,
                                        xml_element)
            # Ref attributes resolve to the global declaration they
            # reference — the particle carries no name of its own.
            # The raw list stays for the required check (use lives on
            # the particle, not the declaration).
            resolved_attributes =
              resolve_schema_attributes(schema_attributes, repository)
            xml_attributes = xml_element.attributes
            wildcards = collect_any_attribute(schema_element, repository,
                                              xml_element)

            # Step 1: Check required attributes are present
            validate_required_attributes(xml_element, schema_attributes,
                                         resolved_attributes,
                                         xml_attributes, collector)

            # Step 1b: Check prohibited attributes are absent — the
            # declaration exists, its USE does not (attF001). Three
            # suite-arbitrated exemptions: a wildcard that admits the
            # attribute shadows the prohibition (attZ002); fixed plus
            # prohibited is an illegal declaration combo and the suite
            # treats the whole declaration as inert (attP031); and a
            # prohibition arriving through DERIVATION is refinement
            # incoherence the suite ignores (attZ007v, attZ015).
            validate_prohibited_attributes(xml_element, schema_attributes,
                                           xml_attributes, collector,
                                           wildcards: wildcards)

            # Step 2: Validate attribute values
            validate_attribute_values(xml_element, resolved_attributes,
                                      xml_attributes, collector,
                                      repository: repository,
                                      schema_element: schema_element,
                                      raw_attrs: schema_attributes)

            # Step 3: Check for unexpected attributes
            validate_no_unexpected_attributes(xml_element,
                                              resolved_attributes,
                                              xml_attributes, collector,
                                              wildcards: wildcards,
                                              repository: repository,
                                              schema_element: schema_element)
          end

          private

          # @return [Array<Lutaml::Xml::Schema::Xsd::Attribute>] the
          #   declarations ref particles point at (unresolvable refs and
          #   direct declarations pass through).
          def resolve_schema_attributes(schema_attrs, repository)
            schema_attrs.map do |attr|
              ref = attr.ref.to_s
              next attr if ref.empty?

              parts = ref.split(":")
              local = parts.last
              declaration =
                if parts.size == 2 && parts.first == "xml"
                  # xml:base and friends are declared by the spec itself.
                  XmlBuiltins.attribute(local)
                else
                  repository&.resolve_attribute(local, nil)
                end
              declaration || attr
            end
          end

          # Whether the element's effective type is xs:anyType: the
          # declared reference names it, the element declares no type at
          # all (implicit anyType, XSD 1.0 §3.3.2), or xsi:type
          # overrides to it (isDefault072).
          #
          # @return [Boolean]
          def any_type_attributes?(xml_element, schema_element)
            return false unless
              schema_element.is_a?(Lutaml::Xml::Schema::Xsd::Element)

            xsi = xsi_attribute(xml_element, "type")
            if xsi&.value.to_s.match?(/\S/)
              return builtin_any_type?(xsi.value.to_s)
            end

            return true if builtin_any_type?(schema_element.type.to_s)

            schema_element.type.to_s.empty? &&
              schema_element.complex_type.nil? &&
              schema_element.simple_type.nil?
          end

          # @return [Boolean]
          def builtin_any_type?(reference)
            parts = reference.to_s.split(":")
            parts.size == 2 && %w[xs xsd].include?(parts.first) &&
              parts.last == "anyType"
          end

          # Collect all schema attributes from element or type definition
          #
          # @param schema_def [Lutaml::Xsd::Element, Lutaml::Xsd::ComplexType]
          #   Schema definition
          # @return [Array<Lutaml::Xsd::Attribute>]
          def collect_schema_attributes(schema_def, repository = nil,
                                        xml_element = nil)
            attributes = []

            # For elements, get attributes from type — an xsi:type
            # override replaces the declared type.
            if schema_def.is_a?(Lutaml::Xml::Schema::Xsd::Element)
              override = xsi_override_type(schema_def, repository,
                                           xml_element)
              if override
                return collect_schema_attributes(override, repository,
                                                 xml_element)
              end

              type_def = resolve_type(schema_def, repository)
              if type_def
                return collect_schema_attributes(type_def, repository,
                                                 xml_element)
              end
            end

            # For complex types, collect attributes
            attributes.concat(Array(schema_def.attribute)) if schema_def.attribute

            # Handle attribute groups
            if schema_def.attribute_group
              Array(schema_def.attribute_group).each do |group|
                attributes.concat(expand_attribute_group(group, repository))
              end
            end

            # Handle complex content
            if schema_def.complex_content
              attributes.concat(
                collect_from_complex_content(
                  schema_def.complex_content, repository
                ),
              )
              part = Array(schema_def.complex_content.extension).first ||
                Array(schema_def.complex_content.restriction).first
              # Base attributes flow through both derivations — a
              # restriction narrows them but cannot drop them (XSD 1.0
              # §3.4.2).
              attributes.concat(inherited_attributes(part.base, repository)) if part
            end

            # Handle simple content
            if schema_def.simple_content
              attributes.concat(
                collect_from_simple_content(
                  schema_def.simple_content, repository
                ),
              )
              part = Array(schema_def.simple_content.extension).first ||
                Array(schema_def.simple_content.restriction).first
              attributes.concat(inherited_attributes(part.base, repository)) if part
            end

            override_base_prohibitions(schema_def, attributes)
            attributes
          end

          # A derived type's OWN (type-level or derivation-body)
          # non-prohibited declaration for a name overrides the base
          # chain's prohibited (attZ007v: the extension re-adds att1
          # required over Two's prohibited). A restriction body's own
          # prohibited stands against the inherited plain declaration
          # (attZ007i: e2 carrying att1 is invalid).
          #
          # @return [void]
          def override_base_prohibitions(schema_def, attributes)
            own_declarations = Array(schema_def.attribute)
            content = schema_def.complex_content || schema_def.simple_content
            CONTENT_PART_KINDS.each do |kind|
              part = content && Array(content.public_send(kind)).first
              own_declarations += Array(part&.attribute) if part
            end
            own_names = own_declarations
              .reject { |a| a.use.to_s == "prohibited" }
              .map { |a| a.name.to_s }
            attributes.reject! do |a|
              a.use.to_s == "prohibited" &&
                own_names.include?(a.name.to_s) &&
                !own_declarations.include?(a)
            end
          end

          # The base type's attribute set flows into the derived type
          # through extension and restriction alike.
          #
          # @return [Array<Lutaml::Xml::Schema::Xsd::Attribute>]
          def inherited_attributes(base_name, repository)
            local = base_name.to_s.split(":").last
            return [] if local.to_s.empty?

            base = repository&.resolve_named_type(local)
            return [] unless base.is_a?(Lutaml::Xml::Schema::Xsd::ComplexType)

            collect_schema_attributes(base, repository)
          end

          # The xsi:type override's type for an instance element, when
          # the override resolves to a named type.
          #
          # @return [Object, nil]
          def xsi_override_type(_schema_element, repository, xml_element)
            return nil unless xml_element

            xsi = xsi_attribute(xml_element, "type")
            return nil unless xsi&.value.to_s.match?(/\S/)

            repository&.resolve_named_type(xsi.value.to_s.split(":").last)
          end

          # Resolve type from element
          #
          # @param element [Lutaml::Xsd::Element] Schema element
          # @return [Lutaml::Xsd::ComplexType, nil]
          def resolve_type(element, repository = nil)
            return element.complex_type if element.complex_type
            return nil unless element.type

            resolved = repository&.resolve_type(element)
            resolved if resolved.is_a?(Lutaml::Xml::Schema::Xsd::ComplexType)
          end

          # Expand attribute group reference
          #
          # @param group [Lutaml::Xsd::AttributeGroup] Attribute group
          # @return [Array<Lutaml::Xsd::Attribute>]
          def expand_attribute_group(group, repository = nil, depth = 0)
            return [] if depth > 5
            return [] unless group

            own = (group.name || group.ref).to_s.split(":").last
            # use=prohibited is illegal inside an attributeGroup
            # DEFINITION (attZ015): the suite ignores such members.
            attrs = Array(group.attribute).reject do |attr|
              attr.use.to_s == "prohibited"
            end

            # An attributeGroup may reference other attributeGroups —
            # their declarations flow into the expansion (attgD004). A
            # reference to the group's OWN name inside an xs:redefine
            # body is the §4.2.2 hook to the ORIGINAL definition.
            Array(group.attribute_group).each do |nested_ref|
              local = (nested_ref.ref || nested_ref.name).to_s
                .split(":").last
              declaration =
                if !local.empty? && local == own &&
                    repository&.redefined_original_for(local)
                  repository.redefined_original_for(local)
                else
                  repository&.resolve_attribute_group(local)
                end
              next unless declaration

              attrs.concat(expand_attribute_group(declaration, repository,
                                                  depth + 1))
            end
            return attrs if attrs.any?

            local = (group.ref || group.name).to_s.split(":").last
            declaration = repository&.resolve_attribute_group(local)
            return [] unless declaration

            expand_attribute_group(declaration, repository, depth + 1)
          end

          # Collect attributes from complex content
          #
          # @param complex_content [Lutaml::Xsd::ComplexContent]
          # @param repository [SchemaDefinitionResolver, nil]
          # @return [Array<Lutaml::Xsd::Attribute>]
          def collect_from_complex_content(complex_content, repository = nil)
            collect_from_content(complex_content, repository)
          end

          # Collect attributes from simple content
          #
          # @param simple_content [Lutaml::Xsd::SimpleContent]
          # @param repository [SchemaDefinitionResolver, nil]
          # @return [Array<Lutaml::Xsd::Attribute>]
          def collect_from_simple_content(simple_content, repository = nil)
            collect_from_content(simple_content, repository)
          end

          # Extension and restriction shapes carry both attribute and
          # attributeGroup collections.
          #
          # @param content [Object]
          # @param repository [SchemaDefinitionResolver, nil]
          # @return [Array<Lutaml::Xsd::Attribute>]
          def collect_from_content(content, repository)
            attributes = []

            %i[extension restriction].each do |shape|
              part = content.public_send(shape)
              next unless part

              attributes.concat(Array(part.attribute))
              Array(part.attribute_group).each do |group|
                attributes.concat(expand_attribute_group(group, repository))
              end
            end

            attributes
          end

          # Validate required attributes are present
          #
          # @param xml_element [XmlElement] The element
          # @param schema_attrs [Array<Lutaml::Xsd::Attribute>] Schema attrs
          # @param xml_attrs [Array<XmlAttribute>] XML attributes
          # @param collector [ResultCollector] Result collector
          # @return [void]
          def validate_required_attributes(xml_element, schema_attrs,
                                           resolved_attrs, xml_attrs,
                                           collector)
            schema_attrs.each_with_index do |schema_attr, index|
              next unless attribute_required?(schema_attr)

              # Ref particles carry no name — the resolved declaration
              # does (addC001: ref="xml:base" use="required").
              attr_name = schema_attr.name.to_s
              if attr_name.empty?
                attr_name = resolved_attrs[index]&.name.to_s
              end
              next if attr_name.empty?

              found = xml_attrs.any? { |xa| xa.name == attr_name }
              next if found

              report_error(
                collector,
                code: "required_attribute_missing",
                message: "Required attribute '#{attr_name}' is missing",
                location: xml_element.xpath,
                context: {
                  attribute: attr_name,
                  element: xml_element.name,
                },
                suggestion: "Add attribute: #{attr_name}=\"...\"",
              )
            end
          end

          # Check if attribute is required
          #
          # @param schema_attr [Lutaml::Xsd::Attribute] Schema attribute
          # @return [Boolean]
          def attribute_required?(schema_attr)
            return false unless schema_attr.use

            schema_attr.use == "required"
          end

          # A prohibited attribute is DECLARED but its use is banned:
          # any instance occurrence violates the schema (attF001).
          #
          # @return [void]
          def validate_prohibited_attributes(xml_element, schema_attrs,
                                             xml_attrs, collector,
                                             wildcards: [])
            schema_attrs.each do |schema_attr|
              next unless schema_attr.use.to_s == "prohibited"
              # fixed + prohibited is an illegal declaration combo
              # (attP031): the suite treats the declaration as inert.
              next if schema_attr.fixed

              attr_name = schema_attr.name.to_s
              next if attr_name.empty?

              xml_attr = xml_attrs.find { |xa| xa.name == attr_name }
              next unless xml_attr
              next if wildcards.any? do |wildcard|
                wildcard_permits_attribute?(wildcard, xml_element, xml_attr,
                                            nil)
              end

              report_error(
                collector,
                code: "prohibited_attribute_present",
                message: "Attribute '#{attr_name}' is prohibited here " \
                         "but present",
                location: xml_element.xpath,
                context: {
                  attribute: attr_name,
                  element: xml_element.name,
                },
                suggestion: "Remove attribute: #{attr_name}",
              )
            end
          end

          # Validate attribute values
          #
          # @param xml_element [XmlElement] The element
          # @param schema_attrs [Array<Lutaml::Xsd::Attribute>] Schema attrs
          # @param xml_attrs [Array<XmlAttribute>] XML attributes
          # @param collector [ResultCollector] Result collector
          # @return [void]
          def validate_attribute_values(xml_element, schema_attrs, xml_attrs,
                                        collector, repository: nil,
                                        schema_element: nil, raw_attrs: [])
            xml_attrs.each do |xml_attr|
              schema_attr = find_schema_attribute(schema_attrs, xml_attr,
                                                  repository, schema_element)
              next unless schema_attr

              # A ref's use site may carry facets the global declaration
              # lacks (attLa005: ref="x:ga1" fixed="abc" at the use
              # site); the instance value is checked against them too.
              use_site = raw_attrs.find do |r|
                r.name == schema_attr.name ||
                  r.ref.to_s.split(":").last == schema_attr.name
              end
              validate_attribute_value(xml_element, xml_attr, schema_attr,
                                       collector,
                                       repository: repository,
                                       use_site: use_site)
            end
          end

          # Find schema attribute definition for XML attribute
          #
          # @param schema_attrs [Array<Lutaml::Xsd::Attribute>] Schema attrs
          # @param xml_attr [XmlAttribute] XML attribute
          # @param repository [SchemaDefinitionResolver, nil]
          # @return [Lutaml::Xsd::Attribute, nil]
          def find_schema_attribute(schema_attrs, xml_attr, repository = nil,
                                    schema_element = nil)
            matches = schema_attrs.select { |sa| sa.name == xml_attr.name }
            return nil if matches.empty?

            # Local declarations carry their own form/attributeFormDefault
            # resolution, precomputed at index time (attMb/attMc/attLb).
            exact = matches.find do |sa|
              expected = repository&.expected_attribute_namespace(sa)
              (expected || repository&.target_namespace_for(sa).to_s) ==
                xml_attr.namespace_uri.to_s
            end
            return exact if exact

            unqualified = matches.find do |sa|
              xml_attr.namespace_uri.to_s.empty? &&
                repository&.expected_attribute_namespace(sa).to_s.empty? &&
                !repository&.expected_attribute_namespace(sa).nil?
            end
            return unqualified if unqualified

            # attributeFormDefault="qualified": local attributes expect
            # the owner schema's target namespace even unindexed — but
            # never over an explicit form on the declaration itself.
            afq = repository&.attribute_form_default_for(schema_element)
              .to_s == "qualified"
            if afq && xml_attr.namespace_uri.to_s.match?(/\S/)
              tns = repository&.target_namespace_for(schema_element).to_s
              if tns == xml_attr.namespace_uri.to_s
                return matches.find { |sa| sa.form.to_s.empty? }
              end
            end

            nil
          end

          # A fixed value compares in the value space: whitespace is
          # normalized on both sides per the declared type's whiteSpace
          # facet (addB104: fixed="  123  " with type xs:integer admits
          # "123").
          #
          # @return [Boolean]
          def fixed_value_matches?(value, schema_attr, fixed_override = nil)
            fixed = fixed_override || schema_attr.fixed
            rule = attribute_whitespace_rule(schema_attr)
            canonical_lexical(value, rule) ==
              canonical_lexical(fixed, rule)
          end

          # @return [Symbol] :preserve, :replace or :collapse
          def attribute_whitespace_rule(schema_attr)
            reference = schema_attr.type.to_s
            return :preserve unless builtin_type_name?(reference)

            local = reference.split(":").last
            return :preserve if local == "string"
            return :replace if local == "normalizedString"

            :collapse
          end

          # @return [String]
          def canonical_lexical(value, rule)
            case rule
            when :collapse
              value.to_s.gsub(/\s+/, " ").strip
            when :replace
              value.to_s.gsub(/[\t\n\r]/, " ")
            else
              value.to_s
            end
          end

          # Validate single attribute value
          #
          # @param xml_element [XmlElement] The element
          # @param xml_attr [XmlAttribute] XML attribute
          # @param schema_attr [Lutaml::Xsd::Attribute] Schema attribute
          # @param collector [ResultCollector] Result collector
          # @return [void]
          def validate_attribute_value(xml_element, xml_attr, schema_attr,
                                       collector, repository: nil,
                                       use_site: nil)
            value = xml_attr.value
            fixed = if use_site && !use_site.fixed.nil?
                      use_site.fixed
                    else
                      schema_attr.fixed
                    end

            # Check fixed value constraint
            if fixed
              unless fixed_value_matches?(value, schema_attr, fixed)
                report_error(
                  collector,
                  code: "fixed_attribute_value_mismatch",
                  message: "Attribute '#{xml_attr.name}' must have fixed " \
                           "value '#{fixed}'",
                  location: xml_element.xpath,
                  context: {
                    attribute: xml_attr.name,
                    expected: fixed,
                    actual: value,
                  },
                )
              end
              return
            end

            # Validate against type definition
            validate_attribute_type(xml_element, xml_attr, schema_attr,
                                    collector, repository: repository)
          end

          # Validate attribute type
          #
          # Resolves the attribute's declared type (built-in reference,
          # named simpleType, or inline simpleType) and validates the
          # lexical value against it.
          #
          # @param xml_element [XmlElement] The element
          # @param xml_attr [XmlAttribute] XML attribute
          # @param schema_attr [Lutaml::Xsd::Attribute] Schema attribute
          # @param collector [ResultCollector] Result collector
          # @param repository [SchemaDefinitionResolver, nil]
          # @return [void]
          def validate_attribute_type(xml_element, xml_attr, schema_attr,
                                      collector, repository: nil)
            violation = attribute_type_violation(xml_attr.value, schema_attr,
                                                 repository, 0)
            return unless violation

            report_error(
              collector,
              code: violation[:code],
              message: "Attribute '#{xml_attr.name}' " \
                       "#{violation[:message]}",
              location: xml_element.xpath,
              context: { attribute: xml_attr.name }.merge(
                violation[:context] || {},
              ),
            )
          end

          # @return [Hash, nil] nil when the value is valid or the type
          #   cannot be resolved
          def attribute_type_violation(value, schema_attr, repository, depth)
            return nil if depth > 6

            if schema_attr.simple_type
              return simple_type_violation(value, schema_attr.simple_type,
                                           repository, depth + 1)
            end
            return nil unless schema_attr.type.to_s.match?(/\S/)

            type_name = schema_attr.type.to_s
            if builtin_type_name?(type_name)
              return builtin_violation(type_name, value)
            end

            named = repository&.resolve_named_type(type_name.split(":").last)
            return nil unless simple_type_model?(named)

            simple_type_violation(value, named, repository, depth + 1)
          end

          def simple_type_model?(type)
            type.is_a?(Lutaml::Xsd::SimpleType) ||
              type.is_a?(Lutaml::Xml::Schema::Xsd::SimpleType)
          end

          def builtin_type_name?(type_name)
            type_name.split(":").first.to_s.match?(/xs|xsd\z/)
          end

          # @return [Hash, nil]
          def builtin_violation(type_name, value)
            answer = lexical_answer(type_name, value)
            if answer.nil?
              engine = validation_engine
              answer = engine&.builtin_valid?(type_name, value)
            end
            return nil if answer.nil? || answer

            {
              code: "attribute_lexical_violation",
              message: "has value '#{value}' that is not a valid " \
                       "#{type_name}",
              context: { value: value, type: type_name },
            }
          end

          # @return [Hash, nil]
          def simple_type_violation(value, simple_type, repository, depth)
            return nil if depth > 6

            if simple_type.list
              return list_violation(value, simple_type.list, repository,
                                    depth)
            end
            if simple_type.union
              return union_violation(value, simple_type.union, repository,
                                     depth)
            end

            restriction = simple_type.restriction
            return nil unless restriction

            restriction_violation(value, restriction, repository, depth)
          end

          def list_violation(value, list, repository, depth)
            local = list.item_type.to_s.split(":").last
            item_type = if builtin_type_name?(list.item_type.to_s)
                          nil
                        else
                          repository&.resolve_named_type(local)
                        end
            items = value.to_s.split(/\s+/).reject(&:empty?)
            items.each do |item|
              violation =
                if item_type
                  simple_type_violation(item, item_type, repository,
                                        depth + 1)
                elsif builtin_type_name?(list.item_type.to_s)
                  builtin_violation(list.item_type.to_s, item)
                end
              next unless violation

              return violation.merge(
                message: "has list item '#{item}' that " \
                         "#{violation[:message]}",
              )
            end
            nil
          end

          def union_violation(value, union, repository, depth)
            members = union.member_types.to_s.split(/\s+/)
            violations = members.filter_map do |ref|
              if builtin_type_name?(ref)
                builtin_violation(ref, value)
              else
                member = repository&.resolve_named_type(ref.split(":").last)
                next nil unless simple_type_model?(member)

                simple_type_violation(value, member, repository, depth + 1)
              end
            end
            return nil if violations.size < members.size

            violations.first
          end

          def restriction_violation(value, restriction, repository, depth)
            base_violation(value, restriction, repository, depth) ||
              facet_violations(value, restriction, repository, depth).first
          end

          # The restriction's base chain is validated first: a built-in
          # base lexically, a named simpleType base recursively.
          def base_violation(value, restriction, repository, depth)
            base = restriction.base.to_s
            return nil unless base.match?(/\S/)

            if builtin_type_name?(base)
              builtin_violation(base, value)
            else
              named = repository&.resolve_named_type(base.split(":").last)
              return nil unless simple_type_model?(named)

              simple_type_violation(value, named, repository, depth + 1)
            end
          end

          # @return [Array<Hash>] every violated facet (first wins)
          def facet_violations(value, restriction, repository, depth)
            violations = []
            violations << enumeration_violation(value, restriction)
            violations << pattern_violation(value, restriction)
            unless forbidden_length_base?(restriction, repository, depth)
              violations << length_violation(value, restriction)
            end
            violations << range_violation(value, restriction)
            violations.compact
          end

          def forbidden_length_base?(restriction, repository, depth)
            return false if depth > FORBIDDEN_LENGTH_DEPTH_LIMIT

            base = restriction.base.to_s
            return false unless base.match?(/\S/)

            local = base.split(":").last
            return true if FORBIDDEN_LENGTH_BASES.include?(local)

            named = repository&.resolve_named_type(local)
            return false unless simple_type_model?(named)

            named_restriction = named.restriction
            return false unless named_restriction

            forbidden_length_base?(named_restriction, repository,
                                   depth + 1)
          end

          def enumeration_violation(value, restriction)
            allowed = Array(restriction.enumeration).map(&:value)
            return nil if allowed.empty? || allowed.include?(value)

            {
              code: "attribute_enumeration_violation",
              message: "has value '#{value}' that is not among " \
                       "#{allowed.map { |v| "'#{v}'" }.join(', ')}",
              context: { value: value, allowed: allowed },
            }
          end

          def pattern_violation(value, restriction)
            patterns = Array(restriction.pattern)
            return nil if patterns.empty?

            # Pattern facets on one restriction step are alternatives
            # (XSD Part 2 §4.3.4.4) — p16.
            compiled = patterns.filter_map do |pattern|
              pattern_value = pattern.value || pattern.to_s
              begin
                [pattern_value, XsdRegex.to_regexp(pattern_value)]
              rescue RegexpError
                nil
              end
            end
            return nil if compiled.empty?
            return nil if compiled.any? { |(_, regex)| value.match?(regex) }

            pattern_value = compiled.map(&:first).join(" | ")
            {
              code: "attribute_pattern_violation",
              message: "has value '#{value}' that does not match " \
                       "pattern '#{pattern_value}'",
              context: { value: value, pattern: pattern_value },
            }
          end

          def length_violation(value, restriction)
            measured = measured_length(value, restriction)
            length_facet = Array(restriction.length).first
            if length_facet && measured != length_facet.value.to_i
              return length_failure(value, "length", length_facet.value)
            end

            min_length = Array(restriction.min_length).first
            if min_length && measured < min_length.value.to_i
              return length_failure(value, "minLength", min_length.value)
            end

            max_length = Array(restriction.max_length).first
            return nil unless max_length && measured > max_length.value.to_i

            length_failure(value, "maxLength", max_length.value)
          end

          def length_failure(value, facet, bound)
            {
              code: "attribute_length_violation",
              message: "has value '#{value}' whose length violates " \
                       "#{facet}='#{bound}'",
              context: { value: value, facet: facet, bound: bound },
            }
          end

          def range_violation(value, restriction)
            # nil domain (plain numeric/unknown bases) compares
            # numerically via facet_key's fallback, mirroring the
            # element-side range check.
            domain = range_domain(restriction.base)
            RANGE_FACETS.each do |facet, compare|
              facet_values = Array(restriction.public_send(facet))
              next if facet_values.empty?

              bound = facet_values.first.value
              value_key = facet_key(value, domain)
              bound_key = facet_key(bound, domain)
              next unless value_key && bound_key
              next if compare.call(value_key, bound_key)

              return {
                code: "attribute_range_violation",
                message: "has value '#{value}' that violates " \
                         "#{facet}='#{bound}'",
                context: { value: value, facet: facet, bound: bound },
              }
            end
            nil
          end

          # Validate no unexpected attributes
          #
          # @param xml_element [XmlElement] The element
          # @param schema_attrs [Array<Lutaml::Xsd::Attribute>] Schema attrs
          # @param xml_attrs [Array<XmlAttribute>] XML attributes
          # @param collector [ResultCollector] Result collector
          # @param wildcard [AnyAttribute, nil] xs:anyAttribute declaration
          # @param repository [SchemaDefinitionResolver, nil]
          # @return [void]
          def validate_no_unexpected_attributes(xml_element, schema_attrs,
                                                xml_attrs, collector,
                                                wildcards: [], repository: nil,
                                                schema_element: nil)
            xml_attrs.each do |xml_attr|
              # Skip xmlns attributes
              next if xml_attr.name == "xmlns" ||
                xml_attr.prefix == "xmlns"

              # Skip xsi attributes
              next if xml_attr.namespace_uri ==
                "http://www.w3.org/2001/XMLSchema-instance"

              schema_attr = find_schema_attribute(schema_attrs, xml_attr,
                                                  repository, schema_element)
              next if schema_attr

              # xml:lang and friends are declared by the spec, not by
              # the schema document.
              next if xml_attr.namespace_uri == XmlBuiltins::NAMESPACE &&
                XmlBuiltins.attribute(xml_attr.name)

              # The derivation's wildcard UNION admits: any permitting
              # wildcard covers the attribute, and a strict mode on any
              # admitting wildcard still demands a declaration in the
              # attribute's own namespace.
              admitted = false
              strict_undeclared = false
              wildcards.each do |wildcard|
                next unless wildcard_permits_attribute?(wildcard,
                                                        xml_element,
                                                        xml_attr, repository)

                admitted = true
                if wildcard_process_mode(wildcard) == "strict" &&
                    !attribute_declared?(xml_attr, repository)
                  strict_undeclared = true
                end
              end

              if admitted
                if strict_undeclared
                  report_error(
                    collector,
                    code: "wildcard_undeclared_attribute",
                    message: "Attribute '#{xml_attr.qualified_name}' " \
                             "matches xs:anyAttribute with " \
                             "processContents=strict but is not declared",
                    location: xml_element.xpath,
                    context: { attribute: xml_attr.qualified_name },
                  )
                end
                next
              end

              report_error(
                collector,
                code: "unexpected_attribute",
                message: "Attribute '#{xml_attr.qualified_name}' is not " \
                         "allowed here",
                location: xml_element.xpath,
                context: {
                  attribute: xml_attr.qualified_name,
                  element: xml_element.name,
                },
                suggestion: suggest_similar_attribute(xml_attr, schema_attrs),
              )
            end
          end

          # Whether the loaded lutaml-model parses xs:anyAttribute on
          # complexType (the mapping landed after 0.8.121); probed once
          # with a minimal schema.
          def complex_type_wildcard_support?
            @complex_type_wildcard_support ||= begin
              probe = Lutaml::Xml::Schema::Xsd.parse(PROBE_SCHEMA)
              !probe.complex_type.first.any_attribute.nil?
            rescue StandardError
              false
            end
          end

          # The attribute wildcards governing a type: the derivation
          # UNION — a base type's wildcard stays in force beside the
          # extension's own (ctH011: ##local base + ##other extension).
          #
          # @return [Array<AnyAttribute>]
          def collect_any_attribute(schema_def, repository = nil,
                                    xml_element = nil)
            if schema_def.is_a?(Lutaml::Xml::Schema::Xsd::Element)
              override = xsi_override_type(schema_def, repository,
                                           xml_element)
              if override
                return collect_any_attribute(override, repository,
                                             xml_element)
              end

              type_def = resolve_type(schema_def, repository)
              return collect_any_attribute(type_def, repository) if type_def
            end
            return [] unless schema_def

            wildcards = []
            complex_wildcard = schema_def.any_attribute if
              schema_def.is_a?(Lutaml::Xml::Schema::Xsd::ComplexType) &&
                complex_type_wildcard_support?
            wildcards << complex_wildcard if complex_wildcard

            # A wildcard nested in an attributeGroup DECLARATION reaches
            # the type only through the group's resolution — the type's
            # ref particle carries no children of its own (attgD019).
            Array(schema_def.attribute_group).each do |group|
              Array(group.any_attribute).each do |wildcard|
                wildcards << wildcard
              end

              collect_group_wildcards(group, repository, wildcards, 0)
            end

            CONTENT_KINDS.each do |content_kind|
              content = schema_def.public_send(content_kind)
              next unless content

              CONTENT_PART_KINDS.each do |part_kind|
                Array(content.public_send(part_kind)).each do |part|
                  Array(part.any_attribute).each do |wildcard|
                    wildcards << wildcard
                  end
                end
              end
            end

            # The base type's wildcard flows into the derived type
            # through extension and restriction alike.
            base = derivation_base(schema_def, repository)
            wildcards.concat(collect_any_attribute(base, repository)) if base

            wildcards
          end

          # The wildcards of an attributeGroup reference's DECLARATION,
          # following nested attributeGroup refs (depth-guarded).
          #
          # @return [void]
          def collect_group_wildcards(group, repository, wildcards, depth)
            return if depth > 5

            local = (group.ref || group.name).to_s.split(":").last
            return if local.to_s.empty?

            declaration = repository&.resolve_attribute_group(local)
            return unless declaration

            Array(declaration.any_attribute).each do |wildcard|
              wildcards << wildcard
            end

            Array(declaration.attribute_group).each do |nested|
              collect_group_wildcards(nested, repository, wildcards,
                                      depth + 1)
            end
          end

          # The named base type of the derivation shape, when present.
          #
          # @return [Lutaml::Xml::Schema::Xsd::ComplexType, nil]
          def derivation_base(schema_def, repository)
            CONTENT_KINDS.each do |content_kind|
              content = schema_def.public_send(content_kind)
              next unless content

              CONTENT_PART_KINDS.each do |part_kind|
                part = Array(content.public_send(part_kind)).first
                next unless part

                local = part.base.to_s.split(":").last
                next if local.to_s.empty?

                base = repository&.resolve_named_type(local)
                return base if base.is_a?(Lutaml::Xml::Schema::Xsd::ComplexType)
              end
            end

            nil
          end

          # Whether an xs:anyAttribute wildcard's namespace constraint
          # admits the attribute (attributes default to unqualified, so
          # ##local is the common admission).
          #
          # @return [Boolean]
          def wildcard_permits_attribute?(wildcard, parent, xml_attr,
                                          repository)
            ns = xml_attr.namespace_uri.to_s
            target = content_target_namespace(parent, repository).to_s
            case wildcard.namespace.to_s
            when "##any", ""
              true
            when "##other"
              !ns.empty? && ns != target
            when "##local"
              ns.empty?
            when "##targetNamespace"
              ns == target
            else
              # space-separated namespace list (##targetNamespace ##local
              # allowed)
              wildcard.namespace.to_s.split(/\s+/).any? do |entry|
                case entry
                when "##local" then ns.empty?
                when "##targetNamespace" then ns == target
                else entry == ns
                end
              end
            end
          end

          # Whether a strict-wildcard attribute resolves to a global
          # declaration in the attribute's OWN namespace — the
          # unique-name fallback may not answer for a different
          # namespace (wildO006: unprefixed attribute, {ns}name declared).
          #
          # @return [Boolean]
          def attribute_declared?(xml_attr, repository)
            return true if repository.nil?

            declaration = repository.resolve_attribute(
              xml_attr.name, xml_attr.namespace_uri
            )
            return false unless declaration

            expected = repository.expected_attribute_namespace(declaration)
            expected.nil? ||
              expected == xml_attr.namespace_uri.to_s
          end

          # Target namespace of the schema owning the parent's declaration.
          #
          # @return [String, nil]
          def content_target_namespace(parent, repository)
            return nil unless repository

            declaration = repository.resolve(parent.name,
                                             parent.namespace_uri)
            repository.target_namespace_for(declaration) if declaration
          end

          # Suggest similar attribute name
          #
          # @param xml_attr [XmlAttribute] XML attribute
          # @param schema_attrs [Array<Lutaml::Xsd::Attribute>] Schema attrs
          # @return [String, nil]
          def suggest_similar_attribute(_xml_attr, schema_attrs)
            return nil if schema_attrs.empty?

            # Simple suggestion based on available attributes
            attr_names = schema_attrs.filter_map(&:name)
            return nil if attr_names.empty?

            "Did you mean one of: #{attr_names.join(', ')}?"
          end
        end
      end
    end
  end
end
