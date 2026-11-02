# frozen_string_literal: true

module Lutaml
  module Xsd
    module Validation
      # ValidationRule is the base class for all validation rules
      #
      # This abstract class defines the interface that all validation rules
      # must implement. It follows the Template Method pattern, allowing
      # subclasses to define specific validation logic while maintaining
      # a consistent structure.
      #
      # @example Create a custom validation rule
      #   class MyRule < ValidationRule
      #     def category
      #       :structure
      #     end
      #
      #     def validate(document, repository, collector)
      #       # Validation logic here
      #     end
      #   end
      #
      # @example Use a validation rule
      #   rule = MyRule.new(strict: true)
      #   rule.validate(document, repository, collector)
      class ValidationRule
        include WildcardScope

        # Valid rule categories
        CATEGORIES = %i[structure type constraint facet identity].freeze

        # @return [Hash] Rule options
        attr_reader :options

        # Initialize a new ValidationRule
        #
        # @param options [Hash] Rule-specific options
        def initialize(options = {})
          @options = options
          @enabled = options.fetch(:enabled, true)
        end

        # Execute the validation rule
        #
        # This is the main entry point for validation. Rules are
        # element-scoped: the engine calls this once per instance element
        # with the schema argument selected by {#schema_argument}.
        #
        # @abstract
        # @param xml_element [XmlElement] The instance element to validate
        # @param schema_argument [Object, nil] What this rule validates
        #   against (schema element by default; see {#schema_argument})
        # @param collector [ResultCollector] Collector for validation results
        # @param repository [SchemaDefinitionResolver, nil] Named-type
        #   resolution for `type="prefix:Name"` references
        # @return [void]
        #
        # @raise [NotImplementedError] if not implemented by subclass
        def validate(xml_element, schema_argument, collector, repository: nil)
          raise NotImplementedError,
                "#{self.class} must implement #validate"
        end

        # The schema object this rule validates the element against.
        #
        # Defaults to the resolved schema element; rules that need a
        # different shape override this (e.g. the occurrence rule wants
        # the content-model particle).
        #
        # @param schema_def [Object, nil] Resolved schema declaration
        # @param repository [SchemaDefinitionResolver, nil]
        # @return [Object, nil]
        def schema_argument(schema_def, repository: nil) # rubocop:disable Lint/UnusedMethodArgument
          # `repository` is part of the contract; the default selection
          # does not consult it.
          schema_def
        end

        # Whether the rule still runs when no schema declaration resolves.
        #
        # @return [Boolean]
        def runs_without_schema?
          false
        end

        XSI_NAMESPACE = "http://www.w3.org/2001/XMLSchema-instance"

        # Find an xsi:-namespaced attribute on the instance element.
        #
        # @param xml_element [XmlElement]
        # @param name [String] local name (e.g. "nil", "type")
        # @return [XmlAttribute, nil]
        def xsi_attribute(xml_element, name)
          xml_element.attributes.find do |attr|
            attr.name == name && attr.namespace_uri == XSI_NAMESPACE
          end
        end

        # Get the category of this validation rule
        #
        # Categories are used to group rules and execute them in phases:
        # - :structure - Element existence, ordering, namespaces
        # - :type - Type compliance (simple and complex types)
        # - :constraint - Occurrences, patterns, ranges
        # - :facet - Facet validation (length, pattern, etc.)
        # - :identity - Key, keyref, unique constraints
        #
        # @abstract
        # @return [Symbol] The rule category
        #
        # @raise [NotImplementedError] if not implemented by subclass
        def category
          raise NotImplementedError,
                "#{self.class} must implement #category"
        end

        # Get a human-readable description of the rule
        #
        # @abstract
        # @return [String] Rule description
        #
        # @raise [NotImplementedError] if not implemented by subclass
        def description
          raise NotImplementedError,
                "#{self.class} must implement #description"
        end

        # Check if this rule is enabled
        #
        # @return [Boolean]
        def enabled?
          @enabled
        end

        # Disable this rule
        #
        # @return [void]
        def disable!
          @enabled = false
        end

        # Enable this rule
        #
        # @return [void]
        def enable!
          @enabled = true
        end

        # Get rule priority for execution order
        #
        # Rules with lower priority numbers execute first.
        # Default priority is 100.
        #
        # @return [Integer]
        def priority
          @options.fetch(:priority, 100)
        end

        # Check if rule should run for given configuration
        #
        # Category filtering is not implemented in the configuration yet;
        # only the enable flag applies.
        #
        # @param config [ValidationConfiguration] The configuration
        # @return [Boolean]
        def applicable?(_config)
          return false unless enabled?

          true
        end

        # Get option value
        #
        # @param key [Symbol] Option key
        # @param default [Object] Default value if not found
        # @return [Object] Option value
        def option(key, default = nil)
          @options.fetch(key, default)
        end

        # Convert to hash representation
        #
        # @return [Hash]
        def to_h
          {
            class: self.class.name,
            category: category,
            description: description,
            enabled: enabled?,
            priority: priority,
            options: @options,
          }
        end

        # String representation
        #
        # @return [String]
        def to_s
          "#{self.class.name}(category: #{category}, enabled: #{enabled?})"
        end

        # Detailed string representation
        #
        # @return [String]
        def inspect
          "#<#{self.class.name} " \
            "category=#{category.inspect} " \
            "enabled=#{enabled?} " \
            "priority=#{priority}>"
        end

        protected

        # The instance namespace a declaration expects: qualified forms
        # map to the owner schema's target namespace, unqualified forms
        # to none (form / elementFormDefault honored by the resolver).
        #
        # @param schema_element [Object]
        # @param repository [SchemaDefinitionResolver, nil]
        # @return [String, nil]
        def resolve_expected_namespace(schema_element, repository)
          return nil unless repository

          repository.expected_namespace_for(schema_element)
        end

        # Whether an instance child matches a content-model particle.
        # Direct declarations compare name and expected namespace; ref
        # particles name a qualified declaration — the owner schema's
        # target namespace is preferred, then the child's, then the
        # unique-name fallback (parsed particles carry no prefix map).
        #
        # @param child [XmlElement]
        # @param particle [Lutaml::Xsd::Element]
        # @param repository [SchemaDefinitionResolver, nil]
        # @param owner_ns [String, nil] target namespace of the schema
        #   owning the content model
        # @return [Boolean]
        def particle_matches_declaration?(child, particle, repository,
                                          owner_ns = nil)
          ref = particle.ref.to_s
          if ref.empty?
            name = particle.name.to_s
            return false unless name.match?(/\S/) && child.name == name

            namespaces_match?(child.namespace_uri,
                              resolve_expected_namespace(particle,
                                                         repository))
          else
            local = ref.split(":").last
            # owner_ns nil means UNKNOWN (the caller has no owner
            # context), not "no namespace" — resolve(local, nil) only
            # matches no-namespace declarations, and a hint-loaded
            # document can supply a foreign namesake.
            declaration =
              (owner_ns && repository&.resolve(local, owner_ns)) ||
              repository&.resolve(local, child.namespace_uri) ||
              repository&.resolve(local, nil)
            return false unless declaration

            child.name == declaration.name &&
              namespaces_match?(child.namespace_uri,
                                repository.expected_namespace_for(declaration))
          end
        end

        # @return [Boolean]
        def namespaces_match?(instance_ns, expected_ns)
          instance_ns = nil if instance_ns.to_s.empty?
          expected_ns = nil if expected_ns.to_s.empty?

          instance_ns == expected_ns
        end

        # The block tokens in force for an element declaration: its
        # explicit block, else the owning schema's blockDefault. A
        # PRESENT-but-empty block overrides the default with nothing —
        # nil (absent) and "" (explicitly empty) are distinct
        # (XSD 1.0 §3.3.2).
        #
        # @return [Array<String>]
        def effective_block_tokens(schema_element, repository)
          explicit = schema_element.block
          return [] if explicit == ""

          if explicit&.match?(/\S/)
            return explicit.to_s.split(/\s+/)
          end

          default = repository&.block_default_for(schema_element).to_s
          default.match?(/\S/) ? default.split(/\s+/) : []
        end

        # XSD 1.0 §3.3.4: a block containing "substitution" (or #all)
        # on the head declaration forbids replacing it with
        # substitution-group members. The head resolves by local name;
        # parsed particles carry no prefix-to-namespace mapping.
        #
        # @param member_declaration [Object] the resolved member
        #   declaration
        # @return [Boolean]
        def substitution_blocked?(member_declaration, head, _head_local,
                                  repository)
          tokens = effective_block_tokens(head, repository)
          return true if tokens.include?("substitution") ||
            tokens.include?("#all")
          return false unless tokens.intersect?(%w[extension restriction])

          # A member whose own type derives from the head's type by a
          # blocked kind is out too (XSD 1.0 §3.3.4 {disallowed
          # substitutions}); direct derivation only.
          member_local = member_declaration.type.to_s.split(":").last
          head_type_local = head.type.to_s.split(":").last
          return false if member_local.to_s.empty? || head_type_local.to_s.empty?
          return false if member_local == head_type_local

          member_type = repository.resolve_named_type(member_local)
          return false unless member_type

          kind = derivation_kind_from(member_type, head_type_local)
          return false unless kind

          blocked = tokens.include?("#all") ? %w[extension restriction] : tokens
          blocked.include?(kind)
        end

        # The derivation kind of a type when it directly derives from
        # the named base; nil when it does not derive from it. Both
        # content kinds count — a simpleContent extension of a simple
        # base is a derivation (elemT058).
        #
        # @return [String, nil]
        def derivation_kind_from(type, declared_local)
          return nil if declared_local.to_s.empty?

          case type
          when Lutaml::Xml::Schema::Xsd::ComplexType
            part = derivation_part(type)
            return nil unless part
            return nil unless part.base.to_s.split(":").last == declared_local

            part.class.name.include?("Extension") ? "extension" : "restriction"
          when Lutaml::Xml::Schema::Xsd::SimpleType
            restriction = type.restriction
            if restriction &&
                restriction.base.to_s.split(":").last == declared_local
              return "restriction"
            end

            nil
          end
        end

        # The derivation part of a complex type: complexContent's
        # extension/restriction, else simpleContent's.
        #
        # @param type [Lutaml::Xml::Schema::Xsd::ComplexType]
        # @return [Object, nil]
        def derivation_part(type)
          complex = type.complex_content
          if complex
            return Array(complex.extension).first ||
                Array(complex.restriction).first
          end

          simple = type.simple_content
          return nil unless simple

          Array(simple.extension).first || Array(simple.restriction).first
        end

        # Whether the element is genuinely nilled: xsi:nil="true" on a
        # nillable declaration. A nilled element has no content — the
        # content-model and occurrence walks exempt it entirely
        # (QFE1700g2).
        #
        # @param xml_element [XmlElement]
        # @param schema_element [Object, nil]
        # @return [Boolean]
        def nilled_instance?(xml_element, schema_element)
          nil_attr = xsi_attribute(xml_element, "nil")
          return false unless nil_attr
          return false unless nil_attr.value.to_s.match?(/\A(true|1)\z/)

          schema_element&.nillable.to_s.match?(/\A(true|1)\z/) || false
        end

        # XSD 1.0 §3.3.6: substitution-group membership is transitive —
        # a member of a member is a member of the head (elemZ003's
        # chained a←b←c←d←e←f←g hierarchy). The declaration follows its
        # substitutionGroup chain up to the head.
        #
        # @param declaration [Object] the resolved element declaration
        # @param head_local [String] the particle's head local name
        # @param repository [SchemaDefinitionResolver, nil]
        # @param depth [Integer] cycle guard
        # @return [Boolean]
        def substitution_member_of?(declaration, head_local, repository,
                                    depth = 0)
          return false if depth > 10

          head = declaration.substitution_group.to_s.split(":").last
          return false if head.nil? || head.empty?
          return true if head == head_local

          parent = repository&.resolve(head, nil)
          return false unless parent

          substitution_member_of?(parent, head_local, repository, depth + 1)
        end

        # Whether an instance child matches a content-model particle of
        # any kind. Containers match when the child matches any leaf
        # inside them (inner ordering permissive; the outer walk stays
        # sequential). Groups expand to their declaration's container.
        #
        # @param child [XmlElement]
        # @param particle [Object]
        # @param repository [SchemaDefinitionResolver, nil]
        # @param parent [XmlElement, nil] content-model owner, for
        #   wildcard target-namespace resolution
        # @param group_depth [Integer] recursion guard for group refs
        # @return [Boolean]
        def particle_matches_child?(child, particle, repository,
                                    parent: nil, group_depth: 0,
                                    owner_ns: nil)
          case particle
          when Lutaml::Xsd::Element
            particle_matches_declaration?(child, particle, repository,
                                          owner_ns) ||
              substitution_member?(child, particle, repository)
          when Lutaml::Xsd::Any
            wildcard_permits?(particle, parent || child, child, repository)
          when Lutaml::Xml::Schema::Xsd::Group
            expand_group_container(particle, repository,
                                   group_depth).any? do |container|
              particle_matches_child?(child, container, repository,
                                      parent: parent,
                                      group_depth: group_depth + 1,
                                      owner_ns: owner_ns)
            end
          when Lutaml::Xsd::Sequence, Lutaml::Xsd::Choice, Lutaml::Xsd::All
            collect_content_particles(particle).any? do |leaf|
              particle_matches_child?(child, leaf, repository,
                                      parent: parent,
                                      group_depth: group_depth,
                                      owner_ns: owner_ns)
            end
          else
            false
          end
        end

        # Particles declared inside a container, by container kind.
        #
        # @return [Array]
        def collect_content_particles(container)
          case container
          when Lutaml::Xsd::Sequence, Lutaml::Xsd::Choice
            Array(container.element) +
              Array(container.any) +
              Array(container.sequence) +
              Array(container.choice) +
              Array(container.group)
          when Lutaml::Xsd::All
            # xs:all holds bare elements only.
            Array(container.element)
          else
            []
          end
        end

        # Helper method to create validation errors
        #
        # @param collector [ResultCollector] The result collector
        # @param code [String] Error code
        # @param message [String] Error message
        # @param location [String, nil] Error location
        # @param context [Hash, nil] Additional context
        # @param suggestion [String, nil] Suggested fix
        # @return [void]
        def report_error(collector, code:, message:, location: nil,
                         context: nil, suggestion: nil)
          error = ValidationError.new(
            code: code,
            message: message,
            severity: :error,
            location: location,
            context: context,
            suggestion: suggestion,
          )
          collector.add_error(error)
        end

        # Helper method to create validation warnings
        #
        # @param collector [ResultCollector] The result collector
        # @param code [String] Warning code
        # @param message [String] Warning message
        # @param location [String, nil] Warning location
        # @param context [Hash, nil] Additional context
        # @param suggestion [String, nil] Suggested fix
        # @return [void]
        def report_warning(collector, code:, message:, location: nil,
                           context: nil, suggestion: nil)
          warning = ValidationError.new(
            code: code,
            message: message,
            severity: :warning,
            location: location,
            context: context,
            suggestion: suggestion,
          )
          collector.add_warning(warning)
        end

        # Helper method to create validation info messages
        #
        # @param collector [ResultCollector] The result collector
        # @param code [String] Info code
        # @param message [String] Info message
        # @param location [String, nil] Info location
        # @param context [Hash, nil] Additional context
        # @return [void]
        def report_info(collector, code:, message:, location: nil,
                        context: nil)
          info = ValidationError.new(
            code: code,
            message: message,
            severity: :info,
            location: location,
            context: context,
          )
          collector.add_info(info)
        end
      end
    end
  end
end
