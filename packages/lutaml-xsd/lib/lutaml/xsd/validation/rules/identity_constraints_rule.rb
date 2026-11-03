# frozen_string_literal: true

require_relative "../validation_rule"

module Lutaml
  module Xsd
    module Validation
      module Rules
        # Validates xs:key / xs:unique / xs:keyref identity constraints on
        # an instance element.
        #
        # Selector and field XPaths evaluate against the instance subtree.
        # Top-level unions split into one path each; namespace-prefixed
        # steps rewrite to local-name() tests (the adapter resolves no
        # namespace bindings). Scope: constraints declared on the element
        # itself; cross-element keyref scopes and recursive selector depth
        # are backlog items (TODO.conformance.md).
        class IdentityConstraintsRule < ValidationRule
          # A tagged identity value: equality requires BOTH the
          # value-space family and the value to match, so disjoint
          # primitives (float vs decimal, boolean vs numeric) never
          # collide even on identical lexicals.
          ValueKey = Struct.new(:space, :value)

          def category
            :identity
          end

          def description
            "Validates key, keyref and unique identity constraints"
          end

          # Constraint names this rule evaluated during the job. The
          # engine-findings arbitration consults it: the engine's unique
          # check is value-LEXICAL, so its duplicate findings for a
          # constraint the Ruby rule evaluated clean are value-space
          # false positives (idF012/013/014). Instance state lives one
          # registry = one job (IdUniquenessRule pattern).
          #
          # @return [Set<String>]
          def evaluated_constraints
            @evaluated_constraints ||= []
          end

          def validate(xml_element, schema_element, collector,
                       repository: nil)
            # `repository` is part of the element-scoped dispatch contract;
            # identity constraints resolve names against the declaration.
            return unless schema_element.is_a?(Lutaml::Xml::Schema::Xsd::Element)

            # Selector/field namespace prefixes resolve against the owner
            # schema's target namespace (the suite's single-namespace shapes).
            target_ns = repository&.target_namespace_for(schema_element).to_s

            collected = {}

            Array(schema_element.key).each do |constraint|
              evaluated_constraints << constraint.name.to_s if constraint.name
              values = collect_values(xml_element, constraint, collector,
                                      repository, target_ns, :key)
              report_duplicates(collector, xml_element, constraint, values,
                                "duplicate_key_violation")
              collected[constraint.name] = values if constraint.name
            end

            Array(schema_element.unique).each do |constraint|
              evaluated_constraints << constraint.name.to_s if constraint.name
              values = collect_values(xml_element, constraint, collector,
                                      repository, target_ns, :unique)
              report_duplicates(collector, xml_element, constraint, values,
                                "duplicate_unique_violation")
              collected[constraint.name] = values if constraint.name
            end

            Array(schema_element.keyref).each do |constraint|
              evaluated_constraints << constraint.name.to_s if constraint.name
              referred = refer_name(constraint) && collected[refer_name(constraint)]
              next if referred.nil?

              collect_values(xml_element, constraint, collector,
                             repository, target_ns, :keyref).each do |value|
                next if referred.include?(value)

                report_error(
                  collector,
                  code: "keyref_violation",
                  message: "Value '#{value}' does not match any " \
                           "'#{refer_name(constraint)}' key",
                  location: xml_element.xpath,
                  context: { value: value, refer: refer_name(constraint) },
                )
              end
            end
          end

          # The adapted form of a namespace-prefixed wildcard attribute
          # field (@ns:* — adapt_xpath's own emission). The engine xpath
          # answers EMPTY for namespace-uri() on attribute nodes, so
          # these fields select the element's attributes directly.
          ADAPTED_WILDCARD_ATTRIBUTE =
            /\A(?:attribute::?|@)\*\[namespace-uri\(\)='([^']*)'\]\z/

          private

          def collect_values(xml_element, constraint, collector, repository,
                             target_namespace, kind)
            fields = field_xpaths(constraint, target_namespace)
            selector_xpaths(constraint, target_namespace).flat_map do |selector|
              Array(xml_element.moxml_element.xpath(selector)).map do |node|
                values = []
                ambiguous = false
                fields.each do |field|
                  matched = field_nodes(node, field)
                  # A field evaluating to a node-set with more than one
                  # member violates the constraint (XSD 1.0 §3.11.4).
                  ambiguous = true if matched.size > 1
                  values << if matched.first
                              field_node_value(matched.first)
                            else
                              field_supply_value(node, field, repository)
                            end
                end

                if ambiguous
                  report_error(
                    collector,
                    code: "field_node_set_violation",
                    message: "Field #{fields.join(', ')} evaluates to " \
                             "more than one node in '#{node.name}'",
                    location: xml_element.xpath,
                    context: { constraint: constraint.name },
                  )
                  next
                end

                # A qualified node has every field present; an absent
                # field means the node does not contribute a row —
                # except for xs:KEY, where a selected node whose fields
                # do not all evaluate is itself an error (XSD 1.0
                # §3.11.4; xmllint: "Not all fields of key
                # identity-constraint evaluate to a node").
                if values.any?(&:nil?)
                  next nil unless kind == :key
                  next nil if out_of_scope_fields?(values, constraint)

                  report_error(
                    collector,
                    code: "key_field_absent_violation",
                    message: "Not all fields of key '#{constraint.name}' " \
                             "evaluate to a node in '#{node.name}'",
                    location: xml_element.xpath,
                    context: { constraint: constraint.name },
                  )
                  next nil
                end

                canonical = fields.each_with_index.map do |field, index|
                  declared = field_declared_type(node, field, repository)
                  value_key(values[index], declared, repository)
                end
                canonical.length == 1 ? canonical.first : canonical
              end
            end.compact
          end

          # The declared type local name of the field's node: attribute
          # fields resolve through the selector node's declaration's
          # type; element fields through their own declaration — or the
          # instance's xsi:type when it overrides (the field's value
          # space follows the INSTANCE type, idF-class).
          #
          # @return [String, nil]
          def field_declared_type(node, field, repository)
            if field.to_s.start_with?("@")
              attr_local = field.sub(/\A@/, "").sub(/\A[\w.-]+:/, "")
              parent_decl = repository&.resolve(node.name,
                                                node.namespace_uri)
              parent_type = parent_decl&.complex_type ||
                repository&.resolve_type(parent_decl)
              return nil unless parent_type

              repository.declared_attribute_type(parent_type, attr_local)
            else
              override = node.attributes.find do |candidate|
                candidate.name == "type" && candidate.namespace&.uri ==
                  XSI_NAMESPACE
              end
              override_value = override && override.value.to_s
              override_parts = override_value&.split(":")
              override_local = override_parts&.last
              prefixed_builtin =
                override_parts && %w[xs xsd].include?(override_parts.first)
              # The field's value space follows the INSTANCE type — a
              # built-in override (xs:boolean) counts even though no
              # schema document declares it.
              builtin_override = override_local && (
                repository&.resolve_named_type(override_local) ||
                prefixed_builtin
              )
              return override_local if builtin_override

              repository&.resolve(node.name, node.namespace_uri)
                &.type.to_s.split(":").last.then do |t|
                  t.to_s.empty? ? nil : t
                end
            end
          end

          # Identity values compare in the field's VALUE space. Numeric
          # primitives tag the key with their family: decimal and its
          # integer derivatives share one space (decimal 1 equals
          # integer 1, idL090), while float/double are a disjoint
          # primitive (float 1 is NOT decimal 1, idF013) and boolean is
          # its own space (boolean 1 is not decimal 1, idF012). Both
          # sides of a keyref canonicalize the same way, keeping them
          # symmetric.
          #
          # @return [ValueKey, String] a tagged key for typed fields, the
          #   raw lexical otherwise
          def value_key(raw, declared_local, repository)
            case repository&.value_space_family(declared_local)
            when :decimal
              ValueKey.new(:decimal, canonical_field_value(raw))
            when :float
              ValueKey.new(:float, raw.to_s.strip.to_f)
            when :boolean
              boolean_key(raw)
            else
              raw
            end
          end

          # A boolean key from a valid boolean lexical; anything else
          # keeps the raw lexical (the engine flags the invalid value,
          # and grouping stays lexical).
          #
          # @return [ValueKey, String]
          def boolean_key(raw)
            lexical = raw.to_s.strip
            return raw unless %w[true false 0 1].include?(lexical)

            ValueKey.new(:boolean, %w[true 1].include?(lexical))
          end

          # @return [Numeric, String]
          def canonical_field_value(raw)
            s = raw.to_s.strip
            return s unless s.match?(/\A-?\d+(\.\d+)?\z/)

            f = s.to_f
            f == f.to_i ? f.to_i : f
          end

          # @param node [Moxml::Node] attribute or element node
          # @return [String, nil]
          def field_node_value(node)
            case node
            when Moxml::Attribute then node.value
            else node.text
            end
          end

          def field_nodes(node, adapted_field)
            wildcard = adapted_field.match(ADAPTED_WILDCARD_ATTRIBUTE)
            return Array(node.xpath(adapted_field)) unless wildcard

            namespace = Regexp.last_match(1)
            node.attributes.select do |attribute|
              attribute.namespace&.uri == namespace
            end
          end

          # The value an ABSENT attribute field still contributes: the
          # declaration's fixed/default supply (idF016/017). Element
          # fields and unresolvable declarations contribute nothing.
          #
          # @return [String, nil]
          def field_supply_value(node, field, repository)
            return nil unless field.to_s.start_with?("@")

            attr_local = field.sub(/\A@/, "").sub(/\A[\w.-]+:/, "")
            parent_decl = repository&.resolve(node.name, node.namespace_uri)
            parent_type = parent_decl&.complex_type ||
              repository&.resolve_type(parent_decl)
            return nil unless parent_type

            repository.declared_attribute_supply(parent_type, attr_local)
          end

          def report_duplicates(collector, xml_element, constraint, values,
                                code)
            values.group_by(&:itself).each do |value, group|
              next unless group.length > 1

              report_error(
                collector,
                code: code,
                message: "Duplicate value '#{value}' for " \
                         "'#{constraint.name}'",
                location: xml_element.xpath,
                context: {
                  value: value,
                  constraint: constraint.name,
                  occurrences: group.length,
                },
              )
            end
          end

          def selector_xpaths(constraint, target_namespace)
            return [] unless constraint.selector

            selector = constraint.selector
            if selector.is_a?(Lutaml::Xml::Schema::Xsd::Selector)
              xpath_strings(selector.xpath, target_namespace)
            else
              xpath_strings(selector, target_namespace)
            end
          end

          def field_xpaths(constraint, target_namespace)
            Array(constraint.field).flat_map do |field|
              if field.is_a?(Lutaml::Xml::Schema::Xsd::Field)
                xpath_strings(field.xpath, target_namespace)
              else
                xpath_strings(field, target_namespace)
              end
            end
          end

          # Whether an absent field leaves a KEY row VIOLATED rather
          # than uncontributed: a field governed by ANOTHER namespace (a
          # prefixed step outside the constraint's scope — idG029) just
          # drops the row; only unprefixed, in-scope fields make the row
          # an incomplete-key error.
          #
          # @return [Boolean]
          def out_of_scope_fields?(values, constraint)
            raw = raw_fields(constraint)
            values.each_index.any? do |index|
              values[index].nil? && raw[index].to_s.match?(/[\w.-]+:/)
            end
          end

          # The field steps as WRITTEN (unions split the same way the
          # adapted list splits) — the absent-row decision reads the
          # step's own namespace governance from these.
          #
          # @return [Array<String>]
          def raw_fields(constraint)
            Array(constraint.field).flat_map do |field|
              value =
                if field.is_a?(Lutaml::Xml::Schema::Xsd::Field)
                  field.xpath
                else
                  field
                end
              value.to_s.split(/\s*\|\s*/).reject(&:empty?)
            end
          end

          # Selector/field values are either the raw XPath string or the
          # parsed xs:selector/xs:field model whose xpath attribute holds
          # it. Top-level unions split into one path each; prefixed
          # steps rewrite to local-name() tests — the adapter resolves
          # no namespace bindings, so "myNS:t" cannot evaluate as-is.
          def xpath_strings(value, target_namespace)
            case value
            when String
              value.split(/\s*\|\s*/).reject(&:empty?)
                .map { |p| adapt_xpath(p, target_namespace) }
            else
              []
            end
          end

          # Rewrites namespace-prefixed steps to adapter-evaluable tests.
          # A prefixed NAME becomes a local-name() test (prefix-
          # insensitive, equivalent for the suite's single-namespace
          # shapes); a prefixed WILDCARD (`myNS:*`) becomes a
          # namespace-uri() test against the owner schema's target
          # namespace, untranslatable without it.
          #
          # @return [String]
          def adapt_xpath(path, target_namespace)
            adapted = path
              .gsub(/@([\w.-]+):([\w.*-]+)/) do
                name = Regexp.last_match(2)
                if name == "*" && target_namespace.to_s.match?(/\S/)
                  "@*[namespace-uri()='#{target_namespace}']"
                else
                  "@*[local-name()='#{name}']"
                end
              end
              .gsub(/(?<![@\w])([\w.-]+):([\w.*-]+)/) do
                name = Regexp.last_match(2)
                if name == "*"
                  if target_namespace.to_s.match?(/\S/)
                    "*[namespace-uri()='#{target_namespace}']"
                  else
                    "*"
                  end
                else
                  "*[local-name()='#{name}']"
                end
              end
            return adapted unless target_namespace.to_s.match?(/\S/)

            # Unprefixed element steps resolve to the schema's TARGET
            # namespace in identity-constraint XPaths (xmllint de-facto,
            # idH020) — the local-name() test is prefix-insensitive, the
            # same trade the prefixed rewrite makes.
            # The atomic group matters: a plain greedy name followed by
            # (?!:) backtracks (attribut|e) and mangles the attribute
            # axis into a corrupt step.
            adapted.gsub(%r{(^|/)((?>[a-zA-Z_][\w.-]*))(?!:)}) do
              "#{Regexp.last_match(1)}" \
                "*[local-name()='#{Regexp.last_match(2)}']"
            end
          end

          # Keyref `refer` as a string; nil when the model left it
          # unmapped (UninitializedClass — a lutaml-model mapping gap for
          # `map_attribute :refer`).
          def refer_name(constraint)
            refer = constraint.refer
            return nil unless refer.is_a?(String)

            text = refer.split(":").last
            text.to_s.empty? ? nil : text
          end
        end
      end
    end
  end
end
