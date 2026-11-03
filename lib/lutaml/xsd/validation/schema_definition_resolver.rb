# frozen_string_literal: true

module Lutaml
  module Xsd
    module Validation
      # Resolves instance elements to their schema declarations for the
      # rule engine's element-scoped dispatch.
      #
      # Indexes top-level and inline element declarations across the
      # repository's schemas. Namespace matching is strict (a target
      # namespace matches only itself; no-namespace schemas match
      # no-namespace instances) with a unique-name fallback for corpora
      # whose instances omit namespaces.
      #
      # Deliberately not resolved here (rule-engine backlog): dynamic
      # typing via xsi:type and derivation closure.
      class SchemaDefinitionResolver
        # Nested particle accessors per container class — all are declared
        # model attributes (lutaml-model 0.8.114+), so dispatch is by
        # class rather than duck-typed probing. Sequence/Choice cannot
        # nest xs:all, and only xs:all carries bare elements.
        CONTAINER_NESTED_KINDS = {
          Lutaml::Xml::Schema::Xsd::ComplexType => %i[sequence choice all],
          Lutaml::Xml::Schema::Xsd::ExtensionComplexContent =>
            %i[sequence choice all],
          Lutaml::Xml::Schema::Xsd::RestrictionComplexContent =>
            %i[sequence choice all],
          Lutaml::Xml::Schema::Xsd::Group => %i[sequence choice all],
          Lutaml::Xml::Schema::Xsd::Sequence => %i[sequence choice],
          Lutaml::Xml::Schema::Xsd::Choice => %i[sequence choice],
          Lutaml::Xml::Schema::Xsd::All => [].freeze,
        }.freeze
        CONTAINER_LEAF_KINDS = {
          Lutaml::Xml::Schema::Xsd::Sequence => %i[element any group],
          Lutaml::Xml::Schema::Xsd::Choice => %i[element any group],
          Lutaml::Xml::Schema::Xsd::All => %i[element].freeze,
        }.freeze
        CONTENT_KINDS = %i[complex_content simple_content].freeze
        CONTENT_PART_KINDS = %i[extension restriction].freeze

        def initialize(repository)
          @repository = repository
          @namespaces = {}.compare_by_identity
          @expected_namespaces = {}.compare_by_identity
          @block_defaults = {}.compare_by_identity
          @declaration_kinds = {}.compare_by_identity
          @attribute_form_defaults = {}.compare_by_identity
          @expected_attribute_namespaces = {}.compare_by_identity
          @named_types = {}
          @attributes = Hash.new { |hash, key| hash[key] = [] }
          @attribute_groups = {}
          @redefined_originals = {}
          # Parsed xs:redefine target documents: their named types back
          # the redefined bodies (schT3: b-ct/b-st live in the target,
          # which the repository does not hold).
          @redefined_targets = []
          @elements = index_elements
        end

        # Whether the declaration is a top-level (global) element —
        # global declarations govern qualified use only.
        #
        # @param element [Object]
        # @return [Boolean]
        def top_level_declaration?(element)
          @declaration_kinds[element] == :top
        end

        # The owning schema's blockDefault for a declaration — the
        # schema-wide default when the element carries no explicit
        # block (XSD 1.0 §3.3.2).
        #
        # @param element [Object]
        # @return [String, nil]
        def block_default_for(element)
          @block_defaults[element]
        end

        # The owning schema's attributeFormDefault for a declaration —
        # local attributes expect the schema's target namespace when it
        # is "qualified" (XSD 1.0 §3.2.2).
        #
        # @param element [Object]
        # @return [String, nil]
        def attribute_form_default_for(element)
          @attribute_form_defaults[element]
        end

        # The instance namespace an attribute declaration expects:
        # precomputed from the declaration's form and the owner schema's
        # attributeFormDefault; globals resolve qualified.
        #
        # @param attribute [Object]
        # @return [String, nil]
        def expected_attribute_namespace(attribute)
          @expected_attribute_namespaces[attribute]
        end

        # Named attribute-group declaration by local name (for
        # xs:attributeGroup ref expansion in the attribute walk).
        #
        # @param local_name [String]
        # @return [Lutaml::Xml::Schema::Xsd::AttributeGroup, nil]
        def resolve_attribute_group(local_name)
          @attribute_groups[local_name]
        end

        # The pre-redefinition declaration of an attributeGroup that an
        # xs:redefine replaced — the target of the redefining body's
        # self-reference hook.
        #
        # @param local_name [String]
        # @return [Object, nil]
        def redefined_original_for(local_name)
          @redefined_originals[local_name]
        end

        # Owner schema's target namespace for a resolved declaration
        # (parsed element models carry no owner-schema link).
        #
        # @param schema_element [Object]
        # @return [String, nil]
        def target_namespace_for(schema_element)
          @namespaces[schema_element]
        end

        # The namespace a conforming instance element carries for this
        # declaration: the owner schema's target namespace for qualified
        # forms, none for unqualified ones. Global declarations are
        # always qualified; local declarations follow form, defaulting
        # to the schema's elementFormDefault.
        #
        # @param element [Object]
        # @return [String, nil]
        def expected_namespace_for(element)
          return @namespaces[element] unless @expected_namespaces.key?(element)

          @expected_namespaces[element]
        end

        # @param name [String] local element name
        # @param namespace_uri [String, nil] instance element namespace
        # @return [Lutaml::Xml::Schema::Xsd::Element, nil]
        def resolve(name, namespace_uri)
          return nil if name.nil? || name.empty?

          candidates = @elements[name]
          return nil if candidates.empty?

          exact = candidates.find do |_element, namespace, _kind|
            namespace_matches?(namespace, namespace_uri)
          end
          return exact&.first if exact

          # Unique-name fallback for instances that omit namespaces even
          # though the schema declares one. A foreign namespace never
          # falls back.
          return nil unless namespace_uri.to_s.empty?

          candidates.length == 1 ? candidates.first.first : nil
        end

        # Global (top-level) element declaration only. A ref particle
        # names a GLOBAL declaration; the index also holds inline ones,
        # and a qualified local namesake must never satisfy the
        # owner-namespace probe (particlesQ016: ref "foo" unprefixed vs
        # the qualified local foo inside the restricted type).
        #
        # @param local_name [String]
        # @param namespace_uri [String, nil]
        # @return [Lutaml::Xml::Schema::Xsd::Element, nil]
        def resolve_global(local_name, namespace_uri)
          return nil if local_name.nil? || local_name.empty?

          candidates = @elements[local_name]
          return nil if candidates.empty?

          exact = candidates.find do |_element, namespace, kind|
            kind == :top && namespace_matches?(namespace, namespace_uri)
          end
          exact&.first
        end

        # Named type for an element's `type="prefix:Name"` reference.
        #
        # @param schema_element [Lutaml::Xml::Schema::Xsd::Element, nil]
        # @return [Object, nil]
        def resolve_type(schema_element)
          return nil unless schema_element

          reference = schema_element.type
          return nil if reference.nil? || reference.to_s.empty?

          resolve_named_type(reference.to_s.split(":").last)
        end

        # Named complex or simple type by local name.
        #
        # @param local_name [String]
        # @return [Object, nil]
        def resolve_named_type(local_name)
          return nil if local_name.nil? || local_name.empty?
          return @named_types[local_name] if @named_types.key?(local_name)

          result = nil
          schemas.each do |schema|
            result = named_type_in(local_name, schema)
            break if result
          end
          if result.nil?
            @redefined_targets.each do |schema|
              result = named_type_in(local_name, schema)
              break if result
            end
          end
          @named_types[local_name] = result
        end

        # @return [Object, nil]
        def named_type_in(local_name, schema)
          found = Array(schema.complex_type).find do |ct|
            ct.name == local_name
          end
          found ||= Array(schema.simple_type).find do |st|
            st.name == local_name
          end
          found || find_nested_named_type(local_name, schema)
        end

        # Named types declared in documents reached through resolved
        # includes/imports — chameleon types (ctE018) live in a
        # no-namespace include target.
        #
        # @return [Object, nil]
        def find_nested_named_type(local_name, schema, depth = 0)
          return nil if depth > 8

          (Array(schema.include) + Array(schema.import)).each do |nested|
            next unless nested.is_a?(Lutaml::Xml::Schema::Xsd::Schema)

            found = Array(nested.complex_type).find do |ct|
              ct.name == local_name
            end
            found ||= Array(nested.simple_type).find do |st|
              st.name == local_name
            end
            return found if found

            found = find_nested_named_type(local_name, nested, depth + 1)
            return found if found
          end
          nil
        end

        # Builtin numeric types: values compare in the numeric value
        # space (3.0 == 3), unlike strings.
        NUMERIC_BUILTINS = %w[
          decimal float double integer long int short byte
          nonPositiveInteger negativeInteger nonNegativeInteger
          positiveInteger unsignedLong unsignedInt unsignedShort
          unsignedByte
        ].freeze

        # The primitive value-space family a named simple type belongs
        # to: :decimal covers decimal and its integer derivatives (one
        # overlapping space, decimal 1 == integer 1), :float covers
        # float/double (a DISJOINT primitive — float 1 is not decimal 1),
        # :boolean its own. Derived named types resolve through
        # restriction base chains.
        #
        # @param local_name [String]
        # @param depth [Integer] recursion guard
        # @return [Symbol, nil]
        def value_space_family(local_name, depth = 0)
          return nil if depth > 10

          family = if %w[float double].include?(local_name.to_s)
                     :float
                   elsif local_name.to_s == "boolean"
                     :boolean
                   elsif NUMERIC_BUILTINS.include?(local_name.to_s)
                     :decimal
                   end
          return family if family

          named = resolve_named_type(local_name)
          return nil unless named.is_a?(Lutaml::Xml::Schema::Xsd::SimpleType)
          return nil unless named.restriction

          value_space_family(
            named.restriction.base.to_s.split(":").last, depth + 1
          )
        end

        # The declared type local name of an attribute on a complex
        # type: its own attribute list, then the derivation base chain
        # (attributes flow through extension and restriction).
        #
        # @param type [Lutaml::Xml::Schema::Xsd::ComplexType]
        # @param attr_local [String]
        # @param depth [Integer] recursion guard
        # @return [String, nil]
        def declared_attribute_type(type, attr_local, depth = 0)
          return nil if depth > 6
          return nil unless type.is_a?(Lutaml::Xml::Schema::Xsd::ComplexType)

          Array(type.attribute).each do |attr|
            next unless attr.name == attr_local

            return attr.type.to_s.split(":").last if attr.type

            ref_local = attr.ref.to_s.split(":").last
            ref_global = ref_local && resolve_attribute(ref_local, nil)
            return ref_global&.type.to_s.split(":").last if ref_global
          end

          content = type.complex_content || type.simple_content
          return nil unless content

          part = Array(content.extension).first ||
            Array(content.restriction).first
          return nil unless part

          Array(part.attribute).each do |attr|
            next unless attr.name == attr_local

            return attr.type.to_s.split(":").last if attr.type
          end

          declared_attribute_type(
            resolve_named_type(part.base.to_s.split(":").last),
            attr_local, depth + 1
          )
        end

        # The Attribute MODEL declared for attr_local on a complex type:
        # its own attribute list (refs resolve to the global
        # declaration), then the derivation base chain through extension
        # and restriction.
        #
        # @param type [Lutaml::Xml::Schema::Xsd::ComplexType]
        # @param attr_local [String]
        # @param depth [Integer] recursion guard
        # @return [Lutaml::Xml::Schema::Xsd::Attribute, nil]
        def find_declared_attribute(type, attr_local, depth = 0)
          return nil if depth > 6
          return nil unless type.is_a?(Lutaml::Xml::Schema::Xsd::ComplexType)

          Array(type.attribute).each do |attr|
            next unless attr.name == attr_local

            return attr if attr.type

            ref_local = attr.ref.to_s.split(":").last
            ref_global = ref_local && resolve_attribute(ref_local, nil)
            return ref_global if ref_global
          end

          content = type.complex_content || type.simple_content
          return nil unless content

          part = Array(content.extension).first ||
            Array(content.restriction).first
          return nil unless part

          Array(part.attribute).each do |attr|
            next unless attr.name == attr_local

            return attr if attr.type

            ref_local = attr.ref.to_s.split(":").last
            ref_global = ref_local && resolve_attribute(ref_local, nil)
            return ref_global if ref_global
          end

          find_declared_attribute(
            resolve_named_type(part.base.to_s.split(":").last),
            attr_local, depth + 1
          )
        end

        # The value an attribute declaration SUPPLIES when the instance
        # omits it: fixed, else default (XSD 1.0 §3.2.3 — idF016/017).
        #
        # @param type [Lutaml::Xml::Schema::Xsd::ComplexType]
        # @param attr_local [String]
        # @return [String, nil]
        def declared_attribute_supply(type, attr_local)
          declaration = find_declared_attribute(type, attr_local)
          return nil unless declaration

          supplied = [declaration.fixed, declaration.default].compact
            .find { |value| value.to_s.match?(/\S/) }
          supplied&.to_s
        end

        # Global attribute declaration by name (for strict xs:anyAttribute
        # checks).
        #
        # @param name [String] local attribute name
        # @param namespace_uri [String, nil] instance attribute namespace
        # @return [Lutaml::Xml::Schema::Xsd::Attribute, nil]
        def resolve_attribute(name, namespace_uri)
          return nil if name.nil? || name.empty?

          # The xml namespace built-ins are declared by the spec, not by
          # any schema document.
          return XmlBuiltins.attribute(name) if
            namespace_uri == XmlBuiltins::NAMESPACE

          candidates = @attributes[name]
          return nil if candidates.empty?

          exact = candidates.find do |_attribute, namespace|
            namespace_matches?(namespace, namespace_uri)
          end
          return exact&.first if exact

          return nil unless namespace_uri.to_s.empty?

          candidates.length == 1 ? candidates.first.first : nil
        end

        # Named group declaration by local name (for xs:group reference
        # expansion in the content and occurrence walks). Group refs
        # reach across imports (groupB009: an extension body references
        # a group declared in the imported document), so nested
        # resolved schemas are searched too.
        #
        # @param local_name [String]
        # @return [Lutaml::Xml::Schema::Xsd::Group, nil]
        def resolve_group(local_name)
          return nil if local_name.nil? || local_name.empty?

          schemas.each do |schema|
            found = Array(schema.group).find { |g| g.name == local_name }
            return found if found

            found = find_nested_group(local_name, schema)
            return found if found
          end
          nil
        end

        # @return [Object, nil]
        def find_nested_group(local_name, schema, depth = 0)
          return nil if depth > 8

          (Array(schema.include) + Array(schema.import)).each do |nested|
            next unless nested.is_a?(Lutaml::Xml::Schema::Xsd::Schema)

            found = Array(nested.group).find { |g| g.name == local_name }
            return found if found

            found = find_nested_group(local_name, nested, depth + 1)
            return found if found
          end
          nil
        end

        # Content-model particle of the element's type, for occurrence
        # and content-model rules.
        #
        # @param schema_element [Lutaml::Xml::Schema::Xsd::Element]
        # @return [Object, nil]
        def content_model_for(schema_element)
          type = schema_element.complex_type || resolve_type(schema_element)
          particle_for_type(type)
        end

        # Content-model particle of a NAMED type (for xsi:type overrides).
        #
        # @param local_name [String]
        # @return [Object, nil]
        def content_model_for_named(local_name)
          particle_for_type(resolve_named_type(local_name))
        end

        private

        def particle_for_type(type)
          case type
          when Lutaml::Xml::Schema::Xsd::ComplexType
            direct = Array(type.sequence).first ||
              Array(type.choice).first || Array(type.all).first ||
              Array(type.group).first
            return direct if direct

            # Derived types keep their particles under complex_content.
            if type.complex_content
              content = type.complex_content
              part = Array(content.extension).first ||
                Array(content.restriction).first
              return particle_for_type(part) if part
            end

            nil
          when Lutaml::Xml::Schema::Xsd::ExtensionComplexContent,
               Lutaml::Xml::Schema::Xsd::RestrictionComplexContent
            # A derivation body may be a bare group reference — the
            # ref's own minOccurs/maxOccurs govern the expanded model
            # (groupG/groupH class).
            Array(type.sequence).first ||
              Array(type.choice).first || Array(type.all).first ||
              Array(type.group).first
          end
        end

        def schemas
          @schemas ||= @repository.all_schemas.values
        end

        def namespace_matches?(schema_namespace, instance_namespace)
          schema_namespace.to_s.empty? == instance_namespace.to_s.empty? &&
            schema_namespace.to_s == instance_namespace.to_s
        end

        def index_elements
          index = Hash.new { |hash, key| hash[key] = [] }
          # Schemas the repository holds directly must not be re-indexed
          # through another schema's resolved import. Different documents
          # can share a target namespace (schC3's no-namespace include
          # set), so the duplicate key is the serialized document, not
          # the namespace.
          held_signatures = schemas.filter_map do |schema|
            schema_signature(schema)
          rescue StandardError
            nil
          end
          schemas.each do |schema|
            index_schema(index, schema, held_signatures)
          rescue StandardError
            # Repositories can carry unparsable entries (broken packages);
            # they contribute no declarations.
            next
          end
          # Prefer top-level declarations over inline ones.
          index.each_value do |candidates|
            candidates.sort_by! { |_element, _ns, kind| kind == :top ? 0 : 1 }
          end
          index
        end

        # Document signature for duplicate detection; memoized per
        # object (equal-valued models eql? together).
        #
        # @return [Array(String, String)]
        def schema_signature(schema)
          @signatures ||= {}.compare_by_identity
          @signatures[schema] ||= [schema.target_namespace.to_s,
                                   schema.to_xml]
        end

        def index_schema(index, schema, held_signatures = [],
                         chameleon_namespace = nil,
                         chameleon_includer = nil)
          # A no-namespace document reached through xs:include is a
          # chameleon: its declarations adopt the includer's target
          # namespace AND form/derivation defaults (ctE018).
          raw_namespace = schema.target_namespace
          chameleon = raw_namespace.to_s.empty? && chameleon_namespace
          namespace = chameleon ? chameleon_namespace : raw_namespace
          defaults_schema = chameleon ? chameleon_includer : schema
          Array(schema.element).each do |element|
            index_element(index, element, namespace, :top, defaults_schema)
            # A global element's INLINE complexType carries local
            # attribute declarations too — their form resolution was
            # only indexed for named types (idG027/idH025).
            index_local_attributes(element.complex_type, namespace,
                                   defaults_schema)
          end
          Array(schema.complex_type).each do |complex_type|
            index_type(index, complex_type, namespace, schema)
            index_local_attributes(complex_type, namespace, defaults_schema)
          end
          Array(schema.attribute).each do |attribute|
            index_attribute(attribute, namespace)
          end
          Array(schema.attribute_group).each do |group|
            name = group.name.to_s
            @attribute_groups[name] = group unless name.empty?
            Array(group.attribute).each do |member|
              index_local_attribute(member, namespace, defaults_schema)
            end
          end
          Array(schema.group).each do |group|
            each_particle_element(group, schema) do |element|
              index_element(index, element, namespace, :inline,
                            defaults_schema)
            end
          end
          # lutaml-model nests resolved xs:import / xs:include targets
          # as child Schema objects (raw Import models stay for
          # unresolvable locations); their declarations validate too.
          # Only includes pass the includer's namespace down — imports
          # never chameleonize.
          Array(schema.include).each do |nested|
            next unless nested.is_a?(Lutaml::Xml::Schema::Xsd::Schema)
            next if held_signatures.include?(schema_signature(nested))

            index_schema(index, nested, held_signatures, namespace,
                         defaults_schema)
          end
          Array(schema.import).each do |nested|
            next unless nested.is_a?(Lutaml::Xml::Schema::Xsd::Schema)
            next if held_signatures.include?(schema_signature(nested))

            index_schema(index, nested)
          end

          # xs:redefine replaces an attributeGroup with a body whose
          # self-reference is the §4.2.2 hook to the ORIGINAL
          # definition. lutaml-model does NOT chase the redefine
          # target, so the original document is parsed here (relative
          # to the defining file) and indexed; the original
          # declaration is kept for that hook and the redefining body
          # indexed under the name (attgC007/attgD036). Runs after the
          # nested descent so included declarations are already in.
          Array(schema.redefine).each do |red|
            target_path = nil
            base = begin
              File.dirname(@repository.source_path_for(schema))
            rescue StandardError
              nil
            end
            if base && red.schema_path.to_s.match?(/\S/)
              candidate = File.expand_path(red.schema_path.to_s, base)
              target_path = candidate if File.exist?(candidate)
            end
            if target_path
              begin
                target = Lutaml::Xml::Schema::Xsd.parse(
                  File.read(target_path), location: target_path
                )
                @redefined_targets << target
                index_schema(index, target, held_signatures, namespace,
                             defaults_schema)
              rescue StandardError
                nil
              end
            end
            Array(red.attribute_group).each do |group|
              name = group.name.to_s
              next if name.empty?

              original = @attribute_groups[name]
              @redefined_originals[name] = original if original
              @attribute_groups[name] = group
            end
          end
        end

        def index_attribute(attribute, namespace)
          return unless attribute
          return if attribute.name.nil? || attribute.name.empty?

          # Global attributes are always qualified.
          @namespaces[attribute] = namespace
          @expected_attribute_namespaces[attribute] = namespace.to_s
          @attributes[attribute.name] << [attribute, namespace]
        end

        # Attribute declarations carried by a complex type body itself:
        # direct children plus extension/restriction attribute lists
        # (attribute-group members index through their group).
        def index_local_attributes(type, namespace, schema)
          return unless type.is_a?(Lutaml::Xml::Schema::Xsd::ComplexType)

          Array(type.attribute).each do |attribute|
            index_local_attribute(attribute, namespace, schema)
          end
          CONTENT_KINDS.each do |content_kind|
            content = type.public_send(content_kind)
            next unless content

            CONTENT_PART_KINDS.each do |part_kind|
              Array(content.public_send(part_kind)).each do |part|
                Array(part.attribute).each do |attribute|
                  index_local_attribute(attribute, namespace, schema)
                end
              end
            end
          end
        end

        # A local attribute's expected instance namespace: its explicit
        # form wins over the owner schema's attributeFormDefault;
        # qualified forms carry the owner schema's target namespace
        # (XSD 1.0 §3.2.2).
        def index_local_attribute(attribute, namespace, schema)
          return unless attribute
          return if attribute.name.nil? || attribute.name.empty?

          @namespaces[attribute] = namespace
          @expected_attribute_namespaces[attribute] =
            case attribute.form.to_s
            when "qualified"
              namespace.to_s
            when "unqualified"
              ""
            else
              if schema.attribute_form_default.to_s == "qualified"
                namespace.to_s
              else
                ""
              end
            end
        end

        def index_element(index, element, namespace, kind, schema)
          return unless element

          @namespaces[element] = namespace
          @expected_namespaces[element] =
            effective_element_namespace(element, namespace, kind, schema)
          @block_defaults[element] = schema.block_default
          @declaration_kinds[element] = kind
          @attribute_form_defaults[element] = schema.attribute_form_default
          unless element.name.nil? || element.name.empty?
            index[element.name] << [element, namespace, kind]
          end
          if element.complex_type
            index_type(index, element.complex_type, namespace, schema)
          end
        end

        # Form-aware expected namespace (XSD 1.0 §3.3.2): explicit form
        # wins, absent form follows elementFormDefault, and top-level
        # declarations are always qualified.
        def effective_element_namespace(element, namespace, kind, schema)
          form = element.form.to_s
          return nil if form == "unqualified"
          return namespace if form == "qualified"
          return namespace if kind == :top

          schema.element_form_default.to_s == "qualified" ? namespace : nil
        end

        def index_type(index, complex_type, namespace, schema)
          return unless complex_type

          each_particle_element(complex_type, schema) do |element|
            index_element(index, element, namespace, :inline, schema)
          end
        end

        def each_particle_element(node, schema, &)
          return unless node

          if node.is_a?(Array)
            node.each { |child| each_particle_element(child, schema, &) }
            return
          end
          return if visited_particle?(node)

          nested = CONTAINER_NESTED_KINDS[node.class]
          return unless nested

          nested.each do |kind|
            Array(node.public_send(kind)).each do |particle|
              each_particle_element(particle, schema, &) if particle
            end
          end
          (CONTAINER_LEAF_KINDS[node.class] || []).each do |kind|
            Array(node.public_send(kind)).each do |leaf|
              # xs:any wildcards and xs:group references are not element
              # declarations; the index holds Element models only.
              yield leaf if leaf.is_a?(Lutaml::Xml::Schema::Xsd::Element)
            end
          end

          if node.is_a?(Lutaml::Xml::Schema::Xsd::ComplexType)
            walk_complex_content(node, schema, &)
          end
        end

        def walk_complex_content(node, schema, &)
          content = node.complex_content
          return unless content

          %i[extension restriction].each do |kind|
            part = content.public_send(kind)
            each_particle_element(part, schema, &) if part
          end
        end

        # Particle collections can be cyclic in parsed models (a nested
        # sequence pointing back at its container); visit each node once.
        def visited_particle?(node)
          @visited ||= {}.compare_by_identity
          return true if @visited[node]

          @visited[node] = true
          false
        end
      end
    end
  end
end
