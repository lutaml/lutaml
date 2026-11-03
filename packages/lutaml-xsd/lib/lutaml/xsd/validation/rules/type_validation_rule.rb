# frozen_string_literal: true

require_relative "../validation_rule"
require_relative "../xsd_regex"

module Lutaml
  module Xsd
    module Validation
      module Rules
        # TypeValidationRule validates element types
        #
        # This rule checks:
        # - Resolves element type from schema
        # - Validates simple type content
        # - Validates complex type content
        # - Delegates to base type validators and facet validators
        #
        # Based on Jing validator type validation algorithm.
        #
        # @example Using the rule
        #   rule = TypeValidationRule.new
        #   rule.validate(xml_element, schema_element, collector)
        #
        # @see docs/JING_ALGORITHM_PORTING_GUIDE.md Type Validation
        class TypeValidationRule < ValidationRule
          include EngineBacked
          include ValueSpace

          # Rule category
          #
          # @return [Symbol] :type
          def category
            :type
          end

          # Rule description
          #
          # @return [String]
          def description
            "Validates element content against XSD type definitions"
          end

          # Validate element type
          #
          # Validates the element's content against its type definition,
          # handling both simple and complex types.
          #
          # @param xml_element [XmlElement] The XML element to validate
          # @param schema_element [Lutaml::Xsd::Element] The schema element
          # @param collector [ResultCollector] Collector for validation
          #   results
          # @return [void]
          def validate(xml_element, schema_element, collector,
                       repository: nil)
            return unless schema_element

            return if xsi_nil_handled?(xml_element, schema_element, collector)

            type_def = resolve_element_type(schema_element, repository)
            if xsi_type_name(xml_element)
              type_def = resolve_xsi_type(xsi_type_name(xml_element),
                                          repository)
              unless type_def
                # xsi:type may name a built-in — resolve_named_type only
                # sees schema documents (addB028).
                if builtin_override_reference(xml_element)
                  validate_builtin_type(xml_element,
                                        builtin_override_reference(xml_element),
                                        collector,
                                        declared: schema_element)
                  return
                end

                report_error(
                  collector,
                  code: "xsi_type_unknown",
                  message: "xsi:type '#{xsi_type_name(xml_element)}' does " \
                           "not resolve to a known type definition",
                  location: xml_element.xpath,
                  context: { xsi_type: xsi_type_name(xml_element) },
                )
                return
              end

              declared_local = schema_element.type.to_s.split(":").last.to_s
              if declared_local.match?(/\S/)
                override_local = type_def.name.to_s.split(":").last
                unless override_local == declared_local ||
                    validly_derived?(type_def, declared_local, repository)
                  report_error(
                    collector,
                    code: "xsi_type_not_derived",
                    message: "xsi:type '#{xsi_type_name(xml_element)}' is " \
                             "not validly derived from the declared type " \
                             "'#{declared_local}'",
                    location: xml_element.xpath,
                    context: { xsi_type: xsi_type_name(xml_element) },
                  )
                  return
                end
              end

              return if abstract_type_used?(type_def, xml_element, collector)

              if override_blocked?(schema_element, type_def, repository)
                report_error(
                  collector,
                  code: "xsi_type_blocked",
                  message: "xsi:type override on element " \
                           "'#{xml_element.name}' is forbidden by its " \
                           "block facet",
                  location: xml_element.xpath,
                  context: { element: xml_element.name },
                )
                return
              end
            end
            if type_def.nil?
              # A type-less declaration is xs:anyType; its fixed value
              # still constrains the lexical content (isDefault070).
              validate_fixed_content(xml_element, schema_element,
                                     xml_element.text_content, collector)
              return
            end

            case type_def
            when Lutaml::Xsd::SimpleType
              validate_simple_type_content(xml_element, type_def, collector,
                                           repository: repository,
                                           declared: schema_element)
            when Lutaml::Xsd::ComplexType
              return if abstract_type_used?(type_def, xml_element, collector)

              # A fixed value constrains the element as a whole — the
              # complex walk checks the type's model, this checks the
              # declaration's own fixed content (isDefault077).
              validate_fixed_content(xml_element, schema_element,
                                     xml_element.text_content, collector)
              validate_complex_type_content(xml_element, type_def, collector)
            else
              # Handle built-in types
              validate_builtin_type(xml_element, type_def, collector,
                                    declared: schema_element)
            end
          end

          # An abstract complex type can only be used through an
          # xsi:type override naming a DERIVED type — the override
          # itself may not be abstract either (XSD 1.0 §3.4.3).
          #
          # @return [Boolean] true when the error was reported
          def abstract_type_used?(type_def, xml_element, collector)
            return false unless type_def.is_a?(Lutaml::Xsd::ComplexType)
            return false unless type_def.abstract.to_s.match?(/\A(true|1)\z/)

            report_error(
              collector,
              code: "abstract_type_used",
              message: "Type '#{type_def.name}' is abstract and cannot " \
                       "be used as an element's type",
              location: xml_element.xpath,
              context: { element: xml_element.name },
            )
            true
          end

          # XSD 1.0 §3.3.4: an xsi:type override must be validly derived
          # from the declared type — the base chain must reach it. Lists
          # and unions derive from anySimpleType, not from their item or
          # member types, so a pure list/union never qualifies. A union
          # base admits overrides naming a member or validly deriving
          # from one (elemT071); the override's block-kind comes from
          # the member chain (elemT074). Complex types derive through
          # both content kinds — a simpleContent extension of a simple
          # base is a derivation too (elemT058).
          #
          # @return [Boolean]
          def validly_derived?(type, base_local, repository, depth = 0)
            return false if type.nil? || base_local.to_s.empty? || depth > 10

            if depth.zero?
              base = repository&.resolve_named_type(base_local)
              if base.is_a?(Lutaml::Xml::Schema::Xsd::SimpleType) && base.union
                return union_member_derived?(type, base, repository, depth)
              end
            end

            case type
            when Lutaml::Xml::Schema::Xsd::ComplexType
              part = derivation_part(type)
              return false unless part

              next_local = part.base.to_s.split(":").last
              return true if next_local == base_local

              validly_derived?(
                repository&.resolve_named_type(next_local),
                base_local, repository, depth + 1
              )
            when Lutaml::Xml::Schema::Xsd::SimpleType
              restriction = type.restriction
              return false unless restriction

              next_local = restriction.base.to_s.split(":").last
              return true if next_local == base_local

              validly_derived?(
                repository&.resolve_named_type(next_local),
                base_local, repository, depth + 1
              )
            else
              false
            end
          end

          # Whether the override names a member of the declared union or
          # validly derives from one (elemT071: R-A restricting member
          # A is a valid override of Union-A; elemT074's rejection comes
          # from its block, not the derivation).
          #
          # @return [Boolean]
          def union_member_derived?(override, union_base, repository, depth)
            members = union_base.union.member_types.to_s.split(/\s+/)
              .map { |m| m.split(":").last }.reject(&:empty?)
            return false if depth > 10

            members.any? do |member_local|
              override.name.to_s.split(":").last == member_local ||
                validly_derived?(override, member_local, repository,
                                 depth + 1)
            end
          end

          # XSD 1.0 §3.3.4 / §3.4.6: block on the element declaration
          # AND on the declared complexType forbids replacing the type
          # with one derived by the blocked kind. A type-less
          # declaration's implicit xs:anyType participates too: every
          # simple override restricts it, and a complex override's
          # outermost derivation is its kind (elemT026).
          #
          # @return [Boolean]
          def override_blocked?(schema_element, override_type, repository)
            declared_local = schema_element.type.to_s.split(":").last
            kind =
              if declared_local.to_s.empty?
                any_type_derivation_kind(override_type)
              else
                derivation_kind_from(override_type, declared_local) ||
                  member_derivation_kind(override_type, declared_local,
                                         repository)
              end
            return false unless kind

            tokens = effective_block_tokens(schema_element, repository)
            declared = repository&.resolve_named_type(declared_local)
            if declared.is_a?(Lutaml::Xml::Schema::Xsd::ComplexType)
              tokens += declared.block.to_s.split(/\s+/)
            end
            return false if tokens.empty?
            return false unless tokens.include?("#all") ||
              tokens.intersect?(%w[extension restriction])

            blocked = tokens.include?("#all") ? %w[extension restriction] : tokens
            blocked.include?(kind)
          end

          # Derivation kind of an override against a type-less
          # declaration's implicit xs:anyType.
          #
          # @return [String, nil]
          def any_type_derivation_kind(override_type)
            case override_type
            when Lutaml::Xml::Schema::Xsd::SimpleType
              "restriction"
            when Lutaml::Xml::Schema::Xsd::ComplexType
              part = derivation_part(override_type)
              return nil unless part

              part.class.name.include?("Extension") ? "extension" : "restriction"
            end
          end

          # Derivation kind of an override that derives from a MEMBER
          # of the declared union — the member chain supplies the kind
          # for block checks (elemT074: R-A restricts member A →
          # "restriction", so block="restriction" forbids the
          # override).
          #
          # @return [String, nil]
          def member_derivation_kind(override_type, declared_local,
                                     repository)
            declared = repository&.resolve_named_type(declared_local)
            return nil unless
              declared.is_a?(Lutaml::Xml::Schema::Xsd::SimpleType) &&
                declared.union

            declared.union.member_types.to_s.split(/\s+/)
              .map { |m| m.split(":").last }.reject(&:empty?)
              .each do |member|
                kind = derivation_kind_from(override_type, member)
                return kind if kind
              end
            nil
          end

          # The derivation kind of the override type when it directly
          # derives from the declared base; nil otherwise.
          #
          private

          # xsi:nil handling: the attribute may appear only on nillable
          # declarations (regardless of its value), and a nilled element
          # must have no content — character or element. Returns true
          # when the element is nilled (nothing further to validate).
          #
          # @return [Boolean]
          def xsi_nil_handled?(xml_element, schema_element, collector)
            nil_attr = xsi_attribute(xml_element, "nil")
            return false unless nil_attr

            nillable = schema_element.nillable.to_s.match?(/\A(true|1)\z/)

            if nil_attr.value.to_s.match?(/\A(true|1)\z/)
              unless nillable
                report_error(
                  collector,
                  code: "xsi_nil_not_allowed",
                  message: "Element '#{xml_element.name}' is not " \
                           "nillable but carries xsi:nil",
                  location: xml_element.xpath,
                  context: { element: xml_element.name },
                )
                return true
              end

              if xml_element.children.empty? &&
                  xml_element.text_content.to_s.strip.empty?
                return true
              end

              report_error(
                collector,
                code: "xsi_nil_with_content",
                message: "Element '#{xml_element.name}' has xsi:nil but " \
                         "carries content",
                location: xml_element.xpath,
                context: { element: xml_element.name },
              )
              return true
            end

            # xsi:nil="false" still advertises nil handling the
            # declaration forbids; content validates normally.
            unless nillable
              report_error(
                collector,
                code: "xsi_nil_not_allowed",
                message: "Element '#{xml_element.name}' is not " \
                         "nillable but carries xsi:nil",
                location: xml_element.xpath,
                context: { element: xml_element.name },
              )
            end
            false
          end

          # The xsi:type attribute value (local part), or nil.
          #
          # @param xml_element [XmlElement]
          # @return [String, nil]
          def xsi_type_name(xml_element)
            attr = xsi_attribute(xml_element, "type")
            return nil unless attr&.value.to_s.match?(/\S/)

            attr.value.to_s.split(":").last
          end

          # Resolve an xsi:type local name to a named type definition.
          #
          # @param local_name [String]
          # @param repository [SchemaDefinitionResolver, nil]
          # @return [Object, nil]
          def resolve_xsi_type(local_name, repository)
            return nil unless repository

            repository.resolve_named_type(local_name)
          end

          # The xsi:type reference in full (`xsd:boolean`), when it names
          # a built-in type.
          #
          # @param xml_element [XmlElement]
          # @return [String, nil]
          def builtin_override_reference(xml_element)
            reference = xsi_attribute(xml_element, "type")&.value.to_s
            parts = reference.split(":")
            return nil unless parts.size == 2

            prefix, local = parts
            return nil unless %w[xs xsd].include?(prefix)

            "#{prefix}:#{local}"
          end

          # Resolve the type definition for an element
          #
          # @param schema_element [Lutaml::Xsd::Element] Schema element
          # @return [Lutaml::Xsd::SimpleType, Lutaml::Xsd::ComplexType, nil]
          def resolve_element_type(schema_element, repository = nil)
            # Check for inline type definition
            return schema_element.simple_type if
              schema_element.simple_type

            return schema_element.complex_type if
              schema_element.complex_type

            # Check for type reference
            if schema_element.type
              resolved = repository&.resolve_type(schema_element)
              return resolved if resolved

              return schema_element.type
            end

            nil
          end

          # The value a simple-typed element validates against: its text
          # content, or — when the element is empty and the declaration
          # carries a fixed or default value — that supplied value (XSD
          # 1.0 §3.3.3; isDefault005).
          #
          # @param xml_element [XmlElement]
          # @param declared [Lutaml::Xml::Schema::Xsd::Element, nil]
          # @return [String]
          def effective_text(xml_element, declared)
            text = xml_element.text_content.to_s
            return text unless text.strip.empty?
            return text unless declared.is_a?(Lutaml::Xml::Schema::Xsd::Element)

            supplied = [declared.fixed, declared.default].compact.find do |value|
              value.to_s.match?(/\S/)
            end
            supplied.nil? ? text : supplied.to_s
          end

          # XSD 1.0 §3.3.3: a fixed value constrains the element — a
          # non-empty lexical must equal it in the value space
          # (elemQ018). Empty content already validates against the
          # fixed value through effective_text.
          #
          # @return [void]
          def validate_fixed_content(xml_element, declared, value, collector)
            return unless declared.is_a?(Lutaml::Xml::Schema::Xsd::Element)

            fixed = declared.fixed.to_s
            return if fixed.empty?
            return if value.to_s.empty?

            rule = declared_whitespace_rule(declared)
            return if canonical(value.to_s, rule) == canonical(fixed, rule)

            report_error(
              collector,
              code: "fixed_content_value_mismatch",
              message: "Element '#{xml_element.name}' must have fixed " \
                       "value '#{fixed}'",
              location: xml_element.xpath,
              context: {
                element: xml_element.name,
                expected: fixed,
                actual: value,
              },
            )
          end

          # @return [Symbol] :preserve, :replace or :collapse
          def declared_whitespace_rule(declared)
            reference = declared.type.to_s
            local =
              if reference.match?(/\S/)
                return :preserve unless
                  %w[xs xsd].include?(reference.split(":").first)

                reference.split(":").last
              elsif declared.simple_type&.restriction
                declared.simple_type.restriction.base.to_s.split(":").last
              end

            case local
            when "string"
              :preserve
            when "normalizedString"
              :replace
            else
              :collapse
            end
          end

          # @return [String]
          def canonical(value, rule)
            case rule
            when :collapse
              value.to_s.gsub(/\s+/, " ").strip
            when :replace
              value.to_s.gsub(/[\t\n\r]/, " ")
            else
              value.to_s
            end
          end

          # Validate simple type content
          #
          # @param xml_element [XmlElement] The XML element
          # @param simple_type [Lutaml::Xsd::SimpleType] The simple type def
          # @param collector [ResultCollector] Result collector
          # @return [void]
          def validate_simple_type_content(xml_element, simple_type,
                                           collector, repository: nil,
                                           declared: nil)
            value = effective_text(xml_element, declared)
            validate_fixed_content(xml_element, declared, value, collector)

            # Validate base type if present
            if simple_type.restriction
              validate_restriction(value, simple_type.restriction,
                                   xml_element, collector,
                                   repository: repository)
            elsif simple_type.list
              validate_list(value, simple_type.list, xml_element, collector,
                            repository: repository)
            elsif simple_type.union
              validate_union(value, simple_type.union, xml_element, collector,
                             repository: repository)
            end
          end

          # Validate complex type content
          #
          # @param xml_element [XmlElement] The XML element
          # @param complex_type [Lutaml::Xsd::ComplexType] Complex type def
          # @param collector [ResultCollector] Result collector
          # @return [void]
          def validate_complex_type_content(xml_element, complex_type,
                                            collector, repository: nil)
            # Complex type validation is handled by:
            # - AttributeValidationRule for attributes
            # - ContentModelValidationRule for content model
            # This rule focuses on type-level constraints

            # Check for simple content
            if complex_type.simple_content
              validate_simple_content(xml_element, complex_type.simple_content,
                                      collector, repository: repository)
            end
          end

          # Validate restriction facets
          #
          # @param value [String] The value to validate
          # @param restriction [Lutaml::Xsd::RestrictionSimpleType] Restriction
          # @param xml_element [XmlElement] The XML element
          # @param collector [ResultCollector] Result collector
          # @return [void]
          def validate_restriction(value, restriction, xml_element, collector,
                                   repository: nil)
            # Validate base type first
            if restriction.base
              validate_base_type(value, restriction.base, xml_element,
                                 collector)
            end

            # List-derived types: pattern and enumeration facets apply
            # to each ITEM of the list (XSD §4.3.4/4.3.5), and the
            # lexical is whitespace-collapsed first (stH005/stG010).
            if repository &&
                list_derived?(restriction.base.to_s.split(":").last,
                              repository)
              validate_list_item_facets(value, restriction, xml_element,
                                        collector)
              return
            end

            # Validate facets
            validate_facets(value, restriction, xml_element, collector,
                            repository: repository)
          end

          # Pattern/enumeration validation per list item.
          #
          # @return [void]
          def validate_list_item_facets(value, restriction, xml_element,
                                        collector)
            collapsed = value.to_s.gsub(/\s+/, " ").strip
            collapsed.split.each do |item|
              validate_pattern_facets(item, restriction, xml_element,
                                      collector)
              validate_enumeration_facets(item, restriction, xml_element,
                                          collector)
            end
          end

          # Validate base type
          #
          # @param value [String] The value to validate
          # @param base_type [String] The base type name
          # @param xml_element [XmlElement] The XML element
          # @param collector [ResultCollector] Result collector
          # @return [void]
          def validate_base_type(value, base_type, xml_element, collector)
            answer = engine_builtin_answer(base_type, value)
            return if answer.nil? || answer

            report_error(
              collector,
              code: "type_validation_error",
              message: "'#{value}' is not a valid #{base_type}",
              location: xml_element.xpath,
              context: { value: value, type: base_type },
            )
          end

          # Validate facets
          #
          # @param value [String] The value to validate
          # @param restriction [Lutaml::Xsd::RestrictionSimpleType] Restriction
          # @param xml_element [XmlElement] The XML element
          # @param collector [ResultCollector] Result collector
          # @return [void]
          def validate_facets(value, restriction, xml_element, collector,
                              repository: nil)
            # Check each facet type
            validate_pattern_facets(value, restriction, xml_element, collector)
            validate_length_facets(value, restriction, xml_element, collector,
                                   repository: repository)
            validate_range_facets(value, restriction, xml_element, collector)
            validate_enumeration_facets(value, restriction, xml_element,
                                        collector)
          end

          # Validate pattern facets
          #
          # @param value [String] The value
          # @param restriction [Lutaml::Xsd::RestrictionSimpleType] Restriction
          # @param xml_element [XmlElement] The element
          # @param collector [ResultCollector] Result collector
          # @return [void]
          def validate_pattern_facets(value, restriction, xml_element,
                                      collector)
            return unless restriction.pattern

            patterns = Array(restriction.pattern)
            return if patterns.empty?

            # Multiple pattern facets on ONE restriction step are
            # alternatives (XSD Part 2 §4.3.4.4): valid when the value
            # matches any of them (p16). Steps in a derivation chain
            # each get their own call and remain conjunctive.
            candidates = patterns.filter_map do |pattern|
              pattern_value = pattern.value || pattern.to_s
              begin
                [pattern_value, XsdRegex.to_regexp(pattern_value)]
              rescue RegexpError => e
                report_warning(
                  collector,
                  code: "invalid_pattern",
                  message: "Invalid pattern in schema: #{e.message}",
                  location: xml_element.xpath,
                )
                nil
              end
            end
            return if candidates.empty?
            return if candidates.any? { |(_, regex)| value.match?(regex) }

            unmatched = candidates.map(&:first).join(" | ")
            report_error(
              collector,
              code: "pattern_mismatch",
              message: "Value '#{value}' does not match pattern " \
                       "'#{unmatched}'",
              location: xml_element.xpath,
              context: {
                value: value,
                pattern: unmatched,
              },
            )
          end

          # Validate length facets
          #
          # @param value [String] The value
          # @param restriction [Lutaml::Xsd::RestrictionSimpleType] Restriction
          # @param xml_element [XmlElement] The element
          # @param collector [ResultCollector] Result collector
          # @return [void]
          # The value the length facets measure: whitespace-normalized
          # per the restriction's effective whiteSpace — an explicit
          # facet wins, then the builtin base's default; preserve keeps
          # every character (ctD028: "len\t\t" is five characters).
          #
          # @return [String]
          def facet_value(value, restriction)
            case whitespace_mode_for_facets(restriction)
            when :collapse
              value.to_s.gsub(/\s+/, " ").strip
            when :replace
              value.to_s.gsub(/[\t\n\r]/, " ")
            else
              value.to_s
            end
          end

          # @return [Symbol] :preserve, :replace or :collapse
          def whitespace_mode_for_facets(restriction)
            explicit = Array(restriction.white_space).first&.value.to_s
            return explicit.to_sym unless explicit.empty?

            case restriction.base.to_s.split(":").last
            when "string"
              :preserve
            when "normalizedString"
              :replace
            else
              :collapse
            end
          end

          def validate_length_facets(value, restriction, xml_element,
                                     collector, repository: nil)
            # Length facets measure characters/octets/items; QName and
            # NOTATION value spaces are (uri, name) tuples and name
            # references — the suite exempts them from length semantics
            # (QName/NOTATION length families).
            base_local = restriction.base.to_s.split(":").last
            return if %w[QName NOTATION].include?(base_local)

            value_length = measured_length(
              facet_value(value, restriction), restriction,
              repository: repository, base_local: base_local
            )

            # Facet collections are arrays; an empty array must not be
            # treated as a present facet.
            length_facet = Array(restriction.length).first
            if length_facet
              expected_length = length_facet.value.to_i
              if value_length != expected_length
                report_error(
                  collector,
                  code: "length_mismatch",
                  message: "Value length #{value_length} does not equal " \
                           "required length #{expected_length}",
                  location: xml_element.xpath,
                  context: {
                    value: value,
                    expected_length: expected_length,
                    actual_length: value_length,
                  },
                )
              end
            end

            # Check minimum length
            min_length_facet = Array(restriction.min_length).first
            if min_length_facet
              min_length = min_length_facet.value.to_i
              if value_length < min_length
                report_error(
                  collector,
                  code: "min_length_violation",
                  message: "Value length #{value_length} is less than " \
                           "minimum #{min_length}",
                  location: xml_element.xpath,
                  context: {
                    value: value,
                    min_length: min_length,
                    actual_length: value_length,
                  },
                )
              end
            end

            # Check maximum length
            max_length_facet = Array(restriction.max_length).first
            return unless max_length_facet

            max_length = max_length_facet.value.to_i
            return unless value_length > max_length

            report_error(
              collector,
              code: "max_length_violation",
              message: "Value length #{value_length} exceeds maximum " \
                       "#{max_length}",
              location: xml_element.xpath,
              context: {
                value: value,
                max_length: max_length,
                actual_length: value_length,
              },
            )
          end

          # Validate range facets
          #
          # @param value [String] The value
          # @param restriction [Lutaml::Xsd::RestrictionSimpleType] Restriction
          # @param xml_element [XmlElement] The element
          # @param collector [ResultCollector] Result collector
          # @return [void]
          def validate_range_facets(value, restriction, xml_element, collector)
            domain = range_domain(restriction.base)
            RANGE_FACETS.each do |facet, compare|
              facet_values = Array(restriction.public_send(facet))
              next if facet_values.empty?

              bound = facet_values.first.value
              value_key = facet_key(value, domain)
              bound_key = facet_key(bound, domain)
              next unless value_key && bound_key
              next if compare.call(value_key, bound_key)

              report_error(
                collector,
                code: "#{facet}_violation",
                message: "Value '#{value}' violates #{facet}='#{bound}'",
                location: xml_element.xpath,
                context: { value: value, bound: bound, facet: facet },
              )
            end
          end

          # Compares the value and bound as integers, then floats; facets
          # on non-numeric types (dates, strings) are not checked here.
          # Validate enumeration facets
          #
          # @param value [String] The value
          # @param restriction [Lutaml::Xsd::RestrictionSimpleType] Restriction
          # @param xml_element [XmlElement] The element
          # @param collector [ResultCollector] Result collector
          # @return [void]
          def validate_enumeration_facets(value, restriction, xml_element,
                                          collector)
            return unless restriction.enumeration

            enumerations = Array(restriction.enumeration)
            return if enumerations.empty?

            allowed_values = enumerations.map do |enum|
              enum.value || enum.to_s
            end

            return if allowed_values.include?(value)

            report_error(
              collector,
              code: "enumeration_violation",
              message: "Value '#{value}' is not in enumeration",
              location: xml_element.xpath,
              context: {
                value: value,
                allowed_values: allowed_values,
              },
              suggestion: "Use one of: #{allowed_values.join(', ')}",
            )
          end

          # Validate list type
          #
          # @param value [String] The value
          # @param list [Lutaml::Xsd::List] The list definition
          # @param xml_element [XmlElement] The element
          # @param collector [ResultCollector] Result collector
          # @return [void]
          def validate_list(value, list, xml_element, collector,
                            repository: nil)
            items = value.split(/\s+/).reject(&:empty?)
            return if items.empty?

            inline = Array(list.simple_type).first
            if inline.is_a?(Lutaml::Xml::Schema::Xsd::SimpleType) &&
                inline.restriction
              items.each do |item|
                validate_facets(item, inline.restriction, xml_element,
                                collector)
              end
              return
            end

            local = list.item_type.to_s.split(":").last
            return if local.to_s.empty?

            named = repository&.resolve_named_type(local)
            if named.is_a?(Lutaml::Xsd::SimpleType) && named.restriction
              items.each do |item|
                validate_facets(item, named.restriction, xml_element,
                                collector)
              end
              return
            end

            items.each do |item|
              answer = engine_builtin_answer(local, item)
              next if answer.nil? || answer

              report_error(
                collector,
                code: "list_item_violation",
                message: "List item '#{item}' is not a valid #{local}",
                location: xml_element.xpath,
                context: { item: item, item_type: local },
              )
            end
          end

          # Validate union type
          #
          # @param value [String] The value
          # @param union [Lutaml::Xsd::Union] The union definition
          # @param xml_element [XmlElement] The element
          # @param collector [ResultCollector] Result collector
          # @return [void]
          def validate_union(value, union, xml_element, collector,
                             repository: nil)
            return if union_accepts?(value, union, xml_element, collector,
                                     repository)

            report_error(
              collector,
              code: "union_violation",
              message: "Value '#{value}' does not match any member type " \
                       "of the union",
              location: xml_element.xpath,
              context: { value: value },
            )
          end

          # A value is valid when any member of the union accepts it.
          # Members are inline simple types or whitespace-separated
          # type references; dry runs collect into a throwaway collector.
          def union_accepts?(value, union, xml_element, _collector,
                             repository)
            Array(union.simple_type).each do |member|
              dry = ResultCollector.new(ValidationConfiguration.new)
              if member.restriction
                # List-derived member bases are whitespace-collapsed:
                # the raw element text keeps its indentation (stH005).
                member_value = value
                if repository &&
                    list_derived?(
                      member.restriction.base.to_s.split(":").last,
                      repository,
                    )
                  member_value = value.to_s.gsub(/\s+/, " ").strip
                end
                validate_facets(member_value, member.restriction,
                                xml_element, dry)
                return true if dry.errors.empty? && dry.warnings.empty?
              else
                return true
              end
            end

            union.member_types.to_s.split(/\s+/).any? do |ref|
              ref_accepts?(value, ref, xml_element, repository)
            end
          end

          def ref_accepts?(value, ref, xml_element, repository)
            local = ref.to_s.split(":").last
            return false if local.to_s.empty?

            answer = engine_builtin_answer(local, value)
            return answer if [true, false].include?(answer)

            named = repository&.resolve_named_type(local)
            return false unless named.is_a?(Lutaml::Xsd::SimpleType)

            dry = ResultCollector.new(ValidationConfiguration.new)
            if named.restriction
              validate_facets(value, named.restriction, xml_element, dry)
              dry.errors.empty? && dry.warnings.empty?
            else
              true
            end
          end

          # Validate simple content
          #
          # @param xml_element [XmlElement] The element
          # @param simple_content [Lutaml::Xsd::SimpleContent] Simple content
          # @param collector [ResultCollector] Result collector
          # @return [void]
          def validate_simple_content(xml_element, simple_content, collector,
                                      repository: nil)
            # Simple content means element has text content and attributes
            # Validate the text content as a simple type
            if simple_content.extension
              # Extension adds attributes to a simple type
              # Text content validation handled by base type
            elsif simple_content.restriction
              # Restriction constrains a simple type
              value = xml_element.text_content
              validate_restriction(value, simple_content.restriction,
                                   xml_element, collector,
                                   repository: repository)
            end
          end

          # Validate built-in type
          #
          # The engine answers builtin lexical checks when the adapter ships
          # an XSD engine; otherwise validation stays unimplemented here
          # (matching historical behavior).
          #
          # @param xml_element [XmlElement] The element
          # @param type_name [String] The type name
          # @param collector [ResultCollector] Result collector
          # @return [void]
          def validate_builtin_type(xml_element, type_name, collector,
                                    declared: nil)
            value = effective_text(xml_element, declared)
            validate_fixed_content(xml_element, declared, value, collector)
            answer = engine_builtin_answer(type_name, value)
            return if answer.nil?
            return if answer

            report_error(
              collector,
              code: "type_validation_error",
              message: "'#{value}' is not a valid " \
                       "#{type_name}",
              location: xml_element.xpath,
              context: {
                value: value,
                type: type_name,
              },
            )
          end

          # Engine answer for a builtin lexical check, nil when unavailable
          #
          # @param type_name [String] XSD type name (any prefix spelling)
          # @param value [String, nil] The lexical value
          # @return [Boolean, nil]
          def engine_builtin_answer(type_name, value)
            own = lexical_answer(type_name, value)
            return own unless own.nil?

            engine = validation_engine
            return unless engine&.supported?

            engine.builtin_valid?(
              "xs:#{type_name.to_s.split(':').last}", value
            )
          end
        end
      end
    end
  end
end
