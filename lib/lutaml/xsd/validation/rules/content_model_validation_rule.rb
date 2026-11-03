# frozen_string_literal: true

require_relative "../validation_rule"

module Lutaml
  module Xsd
    module Validation
      module Rules
        # ContentModelValidationRule validates content models
        #
        # This rule checks:
        # - xs:sequence (order matters)
        # - xs:choice (one of alternatives)
        # - xs:all (all must appear, order doesn't matter)
        # - Nested sequences/choices
        #
        # Based on Jing validator content model validation algorithm.
        #
        # @example Using the rule
        #   rule = ContentModelValidationRule.new
        #   rule.validate(xml_element, complex_type, collector)
        #
        # @see docs/JING_ALGORITHM_PORTING_GUIDE.md Content Model Validation
        class ContentModelValidationRule < ValidationRule
          # Types whose particle accessors type_particles reads — all are
          # declared model attributes (lutaml-model 0.8.114+).
          COMPLEX_PARTICLE_TYPES = [
            Lutaml::Xml::Schema::Xsd::ComplexType,
            Lutaml::Xml::Schema::Xsd::ExtensionComplexContent,
            Lutaml::Xml::Schema::Xsd::RestrictionComplexContent,
          ].freeze
          COMPLEX_PARTICLE_KINDS = %i[sequence choice all group].freeze

          # Objects that can appear in a particle list. Annotation (and
          # other mapped children) leak into resolved_element_order and
          # must not reach the walk.
          PARTICLE_TYPES = [
            Lutaml::Xsd::Element,
            Lutaml::Xsd::Any,
            Lutaml::Xsd::Sequence,
            Lutaml::Xsd::Choice,
            Lutaml::Xsd::All,
            Lutaml::Xml::Schema::Xsd::Group,
          ].freeze

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
            "Validates element content models (sequence, choice, all)"
          end

          # Validate content model
          #
          # Validates element children against the schema's content model,
          # ensuring correct order (sequence), alternatives (choice), or
          # completeness (all).
          #
          # @param xml_element [XmlElement] The XML element to validate
          # @param schema_def [Lutaml::Xsd::ComplexType, Lutaml::Xsd::Element]
          #   The schema definition
          # @param collector [ResultCollector] Collector for validation results
          # @return [void]
          def validate(xml_element, schema_def, collector, repository: nil)
            return unless schema_def

            # A nilled element has no content to match (QFE1700g2).
            return if nilled_instance?(xml_element, schema_def)

            particles = effective_particles(
              xml_element, schema_def, repository
            )
            # nil: an xsi:type override that does not resolve — the type
            # rule already reports it, so no content walk runs here.
            if particles.nil?
              engine_content_check(xml_element, collector)
              return
            end

            # A type with no particle model at all is EMPTY content:
            # neither element children nor character data.
            if particles.empty?
              report_empty_content_violation(xml_element, schema_def,
                                             collector, repository)
              return
            end

            # The engine does not check abstract-element usage; scan for
            # it regardless of whether the engine answered.
            owner_ns = repository&.target_namespace_for(schema_def)
            scan_abstract_usage(xml_element, particles, collector,
                                repository, owner_ns)

            handled = if occurrence_guard(repository).particles_safe?(particles)
                        engine_content_check(xml_element,
                                             collector) == :handled
                      else
                        # The native engine compiles nested occurrence
                        # products (a unbounded inside sequence{100}) into
                        # automata large enough to have the process killed
                        # (particlesZ034_b); the Ruby matcher decides those.
                        false
                      end
            if handled
              scan_cross_namespace_refs(xml_element, particles, collector,
                                        repository, owner_ns)
              return
            end

            validate_particle_sequence(xml_element, particles, collector,
                                       repository, owner_ns)
          end

          private

          def occurrence_guard(repository)
            OccurrenceProductGuard.new(
              group_expander: ->(group) do
                expand_group_container(group, repository)
              end,
              container_particles: ->(container) { collect_particles(container) },
            )
          end

          # Exact structural membership via the NFA matcher. When the
          # model accepts, the particle walk is skipped — it cannot add
          # anything but noise. When it rejects, the walk supplies its
          # targeted diagnostics; if the walk still finds nothing (its
          # greedy runs can sail through a structure the automaton
          # rejects), the matcher's failure position becomes the error.
          #
          # @return [void]
          def validate_particle_sequence(xml_element, particles, collector,
                                         repository, owner_ns = nil)
            return if particles.empty?

            children = Array(xml_element.children)
            matcher = ContentModelMatcher.new(
              particles,
              element_match: ->(child, particle) do
                element_matches?(child, particle, repository, owner_ns)
              end,
              wildcard_match: ->(child, wildcard) do
                wildcard_permits?(wildcard, xml_element, child, repository)
              end,
              container_particles: ->(container) do
                collect_particles(container)
              end,
              group_particles: ->(group) do
                expand_group_container(group, repository)
              end,
            )
            result = matcher.match(children)
            if result.matched
              scan_wildcard_strict_usage(xml_element, particles, collector,
                                         repository, owner_ns)
              return
            end

            known = collector.errors.size
            walk_sequence_diagnostics(xml_element, particles, collector,
                                      repository, owner_ns)
            return if collector.errors.size > known

            report_matcher_failure(result, children, xml_element, collector)
          end

          def report_matcher_failure(result, children, xml_element, collector)
            if result.fail_reason == :unexpected_child
              child = children[result.fail_index]
              report_error(
                collector,
                code: "unexpected_element_in_sequence",
                message: "Unexpected element '#{child.qualified_name}' " \
                         "in sequence",
                location: child.xpath,
                context: { element: child.qualified_name },
                suggestion: "Remove this element or check sequence order",
              )
            else
              report_error(
                collector,
                code: "incomplete_content_model",
                message: "Element '#{xml_element.qualified_name}' is " \
                         "missing required content",
                location: xml_element.xpath,
                context: { element: xml_element.qualified_name },
              )
            end
          end

          # A type with no particle model at all is EMPTY content:
          # neither element children nor character data.
          #
          # @return [void]
          def report_empty_content_violation(xml_element, schema_def,
                                             collector, repository)
            type = if schema_def.is_a?(Lutaml::Xml::Schema::Xsd::Element)
                     resolve_type(schema_def, repository)
                   else
                     schema_def
                   end
            return unless type.is_a?(Lutaml::Xml::Schema::Xsd::ComplexType)
            return unless empty_content_type?(type)
            return if xml_element.children.empty? &&
              xml_element.text_content.to_s.strip.empty?

            report_error(
              collector,
              code: "empty_content_violation",
              message: "Element '#{xml_element.name}' has an empty " \
                       "content model but carries content",
              location: xml_element.xpath,
              context: { element: xml_element.name },
            )
          end

          # Whether the complex type declares no content model of any
          # kind (attribute-only declarations are empty content). A
          # MIXED type admits character data regardless.
          #
          # @return [Boolean]
          def empty_content_type?(type)
            return false if type.mixed.to_s.match?(/\A(true|1)\z/)

            COMPLEX_PARTICLE_KINDS.each do |kind|
              return false if Array(type.public_send(kind)).any?
            end
            return false if type.simple_content || type.complex_content

            true
          end

          # Particles of the effective type: an xsi:type override wins over
          # the declared type; the walk then consumes the list in order.
          #
          # @return [Array, nil] nil when an xsi:type override does not
          #   resolve to a known type
          def effective_particles(xml_element, schema_def, repository)
            xsi = repository && xsi_attribute(xml_element, "type")
            if xsi&.value.to_s.match?(/\S/)
              local = xsi.value.to_s.split(":").last
              named = repository.resolve_named_type(
                local, repository.target_namespace_for(schema_def)
              )
              return nil unless named

              return type_particles(named, repository, {}.compare_by_identity)
            end

            case schema_def
            when Lutaml::Xml::Schema::Xsd::Element
              type_def = resolve_type(schema_def, repository)
              return [] unless type_def

              type_particles(type_def, repository, {}.compare_by_identity)
            when Lutaml::Xsd::Sequence, Lutaml::Xsd::Choice, Lutaml::Xsd::All
              # A rooted group walks as a single particle: the sequence
              # walk's container handling then matches any leaf in any
              # consecutive run, which is permissive-correct for choice
              # and all without the old ambiguity false positive.
              [schema_def]
            else
              type_particles(schema_def, repository, {}.compare_by_identity)
            end
          end

          # Ordered particles of a type: own sequence/choice/all/group
          # particles plus, for extensions, the base type's particles
          # first. Cycle-guarded. Every container stays whole — the
          # matcher applies its occurrence constraints; a flattened
          # container would drop e.g. a maxOccurs="0" wrapper.
          #
          # @return [Array]
          def type_particles(type, repository, seen)
            return [] if type.nil? || seen.key?(type)
            return [] unless COMPLEX_PARTICLE_TYPES.any? { |k| type.is_a?(k) }

            seen[type] = true
            particles = []

            COMPLEX_PARTICLE_KINDS.each do |kind|
              Array(type.public_send(kind)).each do |particle|
                next unless particle

                # Group refs stay whole too: the matcher expands them
                # under the REF's occurrence bounds — expanding here
                # would drop e.g. a group ref's maxOccurs="2".
                particles << particle
              end
            end

            if type.is_a?(Lutaml::Xml::Schema::Xsd::ComplexType) &&
                type.complex_content
              content = type.complex_content
              extension = Array(content.extension).first
              restriction = Array(content.restriction).first
              if extension
                base_local = extension.base.to_s.split(":").last
                base_type = base_local &&
                  repository&.resolve_named_type(
                    base_local, repository&.target_namespace_for(type)
                  )
                particles = type_particles(base_type, repository, seen) +
                  particles
                COMPLEX_PARTICLE_KINDS.each do |kind|
                  Array(extension.public_send(kind)).each do |particle|
                    next unless particle

                    particles << particle
                  end
                end
              elsif restriction
                # A restriction REPLACES the base content model: only
                # the restriction body's particles apply (groupH008's
                # prohibited group ref was previously compiled as an
                # EMPTY model and the children passed unchecked).
                particles = COMPLEX_PARTICLE_KINDS.flat_map do |kind|
                  Array(restriction.public_send(kind)).compact
                end
              end
            end

            particles
          end

          # Engine-accepted content still needs the checks the engine
          # lacks: abstract element declarations cannot appear in
          # instances. Containers flatten to their leaf declarations —
          # the walk keeps them whole, the scan needs the leaves.
          def scan_abstract_usage(xml_element, particles, collector,
                                  repository, owner_ns = nil)
            leaves = leaf_particles(particles, repository)
            xml_element.children.each do |child|
              leaves.each do |particle|
                next unless particle.is_a?(Lutaml::Xsd::Element)
                next unless particle_matches?(child, particle, repository,
                                              parent: xml_element,
                                              owner_ns: owner_ns)
                next unless element_declaration_abstract?(particle, child,
                                                          repository, owner_ns)

                report_error(
                  collector,
                  code: "abstract_element_used",
                  message: "Element '#{child.qualified_name}' is " \
                           "abstract and cannot appear in the instance",
                  location: child.xpath,
                  context: { element: child.qualified_name },
                )
                break
              end
            end
          end

          def leaf_particles(particles, repository)
            particles.flat_map do |particle|
              case particle
              when Lutaml::Xml::Schema::Xsd::Group
                leaf_particles(expand_group_container(particle, repository),
                               repository)
              when Lutaml::Xsd::Sequence, Lutaml::Xsd::Choice, Lutaml::Xsd::All
                leaf_particles(collect_particles(particle), repository)
              else
                [particle]
              end
            end
          end

          # Wildcards consumed through the automaton bypass the walk's
          # inline strict checks, so children that only a wildcard can
          # cover are scanned here on the accept path.
          #
          # @return [void]
          def scan_wildcard_strict_usage(xml_element, particles, collector,
                                         repository, owner_ns = nil)
            leaves = leaf_particles(particles, repository)
            wildcards = leaves.select { |p| p.is_a?(Lutaml::Xsd::Any) }
            return if wildcards.empty?

            element_leaves = leaves.select do |p|
              p.is_a?(Lutaml::Xml::Schema::Xsd::Element)
            end
            xml_element.children.each do |child|
              next if element_leaves.any? do |p|
                element_matches?(child, p, repository, owner_ns)
              end

              wildcards.each do |wildcard|
                next unless wildcard_permits?(wildcard, xml_element, child,
                                              repository)

                check_strict_wildcard_child(child, wildcard, collector,
                                            repository)
                break
              end
            end
          end

          # Sequential walk over a particle list (min/max per particle,
          # recursive matching, wildcard permission for unmatched tails).
          # Demoted to diagnostics: it runs only after the NFA matcher
          # has already decided the instance is invalid.
          #
          # @return [void]
          def walk_sequence_diagnostics(xml_element, particles, collector,
                                        repository, owner_ns = nil)
            return if particles.empty?

            children = xml_element.children
            child_index = 0

            particles.each do |particle|
              min_occurs = parse_occurs(particle.min_occurs, 1)
              # Container particles (nested sequence/choice/all) consume
              # their whole consecutive run: the walk counts individual
              # children, so a default max of 1 would truncate the group
              # after its first child. Explicit caps on containers are
              # enforced loosely for the same reason.
              container = particle.is_a?(Lutaml::Xsd::Sequence) ||
                particle.is_a?(Lutaml::Xsd::Choice) ||
                particle.is_a?(Lutaml::Xsd::All) ||
                particle.is_a?(Lutaml::Xml::Schema::Xsd::Group)
              max_occurs = parse_max_occurs(
                particle.max_occurs, container ? :unbounded : 1
              )
              matched_count = 0

              # Try to match children against this particle
              while child_index < children.size
                child = children[child_index]

                break unless particle_matches?(child, particle, repository,
                                               parent: xml_element,
                                               owner_ns: owner_ns)

                if particle.is_a?(Lutaml::Xsd::Any)
                  check_strict_wildcard_child(child, particle, collector,
                                              repository)
                elsif particle.is_a?(Lutaml::Xsd::Element) &&
                    element_declaration_abstract?(particle, child, repository,
                                                  owner_ns)
                  report_error(
                    collector,
                    code: "abstract_element_used",
                    message: "Element '#{child.qualified_name}' is " \
                             "abstract and cannot appear in the instance",
                    location: child.xpath,
                    context: { element: child.qualified_name },
                  )
                end

                matched_count += 1
                child_index += 1

                # Stop if we've reached max occurrences
                break if max_occurs != :unbounded &&
                  matched_count >= max_occurs

                # Child doesn't match, move to next particle
              end

              # Check minimum occurrence
              next unless matched_count < min_occurs
              next if particle.is_a?(Lutaml::Xsd::Any) && min_occurs.zero?
              # A container whose content can match the empty sequence
              # occurs trivially (all-of with every child optional).
              if container && container_matches_empty?(particle, repository)
                next
              end

              report_min_occurs_violation(particle, xml_element, collector,
                                          min_occurs, matched_count)
            end

            # Check for unexpected children after sequence
            return unless child_index < children.size

            wildcard = particles.find { |p| p.is_a?(Lutaml::Xsd::Any) }
            unexpected = children[child_index..]
            unexpected.each do |child|
              if wildcard && wildcard_permits?(wildcard, xml_element, child,
                                               repository)
                check_strict_wildcard_child(child, wildcard, collector,
                                            repository)
                next
              end

              report_error(
                collector,
                code: "unexpected_element_in_sequence",
                message: "Unexpected element '#{child.qualified_name}' " \
                         "in sequence",
                location: child.xpath,
                context: {
                  element: child.qualified_name,
                },
                suggestion: "Remove this element or check sequence order",
              )
            end
          end

          # Whether the matched declaration is abstract: abstract element
          # declarations cannot appear directly in instances (substitution
          # members remain legal). Direct declarations carry their own
          # abstract flag; references resolve to the global declaration.
          def element_declaration_abstract?(particle, child, repository,
                                            owner_ns = nil)
            declaration = declaration_for(particle, child, repository,
                                          owner_ns)
            return false unless declaration

            truthy?(declaration.abstract) && child.name == declaration.name
          end

          # A qualified ref names a declaration in ONE namespace.
          # Global names duplicated across namespaces (import + main)
          # resolve against the child's namespace today; a foreign
          # child is an unexpected element (the engine — fed the
          # documents one at a time — admits the substitute, so this
          # runs on the engine-accept path). Wildcard territory is
          # exempt. The PREFIX is the signal: an unprefixed ref
          # canonically names a NO-NAMESPACE declaration (Q016 — its
          # qualified local namesake is irrelevant), a prefixed one
          # names some namespace: a child in the opposite territory,
          # or — for the duplicated-name shape — in any namespace but
          # the owner's, cannot match.
          #
          # @return [void]
          def scan_cross_namespace_refs(xml_element, particles, collector,
                                        repository, owner_ns)
            return if owner_ns.nil?

            refs = leaf_particles(particles, repository).select do |p|
              p.is_a?(Lutaml::Xml::Schema::Xsd::Element) &&
                p.ref.to_s.match?(/\S/)
            end
            return if refs.empty?

            # Several DISTINCT prefixed forms of one local name mean the
            # schema disambiguates by prefix on purpose (particlesQ032:
            # foo:e2 / x:e2 / bar:e2) — the owner-namespace guess is
            # untenable there.
            single_prefixed_form = refs.select do |r|
              r.ref.to_s.include?(":")
            end.group_by { |r| r.ref.to_s.split(":").last }
              .select { |_, group| group.map { |r| r.ref.to_s.split(":").first }.uniq.size == 1 }
              .map(&:first)

            xml_element.children.each do |child|
              child_ns = child.namespace_uri.to_s
              next if child_ns == owner_ns

              hit = refs.find do |r|
                ref = r.ref.to_s
                next false unless ref.split(":").last == child.name

                if ref.include?(":")
                  next false unless single_prefixed_form.include?(child.name)

                  child_ns.empty? ||
                    (child_ns != owner_ns &&
                     repository.resolve_global(child.name, owner_ns))
                else
                  child_ns.match?(/\S/)
                end
              end
              next unless hit
              next if wildcard_covers_child?(xml_element, particles, child,
                                             repository)

              report_error(
                collector,
                code: "unexpected_element_in_sequence",
                message: "Unexpected element '#{child.qualified_name}' " \
                         "in sequence — the reference names the same " \
                         "declaration in another namespace",
                location: child.xpath,
                context: { element: child.qualified_name },
                suggestion: "Use the declaration's namespace or rename " \
                            "the duplicate",
              )
            end
          end

          def wildcard_covers_child?(xml_element, particles, child,
                                     repository)
            leaf_particles(particles, repository).any? do |p|
              next false unless p.is_a?(Lutaml::Xsd::Any)

              wildcard_permits?(p, xml_element, child, repository)
            end
          end

          def declaration_for(particle, child, repository, owner_ns = nil)
            return particle if particle.name.to_s.match?(/\S/)
            return nil unless repository

            local = particle.ref.to_s.split(":").last
            (owner_ns && repository.resolve_global(local, owner_ns)) ||
              repository.resolve(local, child.namespace_uri) ||
              repository.resolve(local, nil)
          end

          def truthy?(value)
            value.to_s == "true"
          end

          # Report an unsatisfied minimum occurrence: a choice container
          # names its alternatives, anything else reports generically.
          #
          # @return [void]
          def report_min_occurs_violation(particle, xml_element, collector,
                                          min_occurs, matched_count)
            if particle.is_a?(Lutaml::Xsd::Choice)
              alternatives = collect_particles(particle).map do |p|
                particle_name(p)
              end
              report_error(
                collector,
                code: "choice_not_satisfied",
                message: "One of the following elements must be present: " \
                         "#{alternatives.join(', ')}",
                location: xml_element.xpath,
                context: { choices: alternatives },
                suggestion: "Add one of: #{alternatives.join(', ')}",
              )
            else
              report_error(
                collector,
                code: "sequence_min_occurs_violation",
                message: "#{display_particle_name(particle)} must occur " \
                         "at least #{min_occurs} time(s)",
                location: xml_element.xpath,
                context: {
                  particle: display_particle_name(particle),
                  min_occurs: min_occurs,
                  actual: matched_count,
                },
              )
            end
          end

          # Engine-first content-model check for this element.
          #
          # @param xml_element [XmlElement] The XML element
          # @param collector [ResultCollector] Collector for results
          # @return [:handled, :skipped] :skipped lets the Ruby walk run
          def engine_content_check(xml_element, collector)
            engine = @options[:engine_context]
            return :skipped unless engine&.supported?

            answer = engine.content_valid(
              xml_element.name, xml_element.moxml_element.children.to_a
            )
            return :skipped if answer.nil?

            unless answer
              report_error(
                collector,
                code: "content_model_error",
                message: "Content of element '#{xml_element.name}' is not " \
                         "valid against its content model",
                location: xml_element.xpath,
              )
            end

            :handled
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

          # @return [Boolean]
          def wildcard_child_declared?(child, repository)
            return true if repository.nil?

            !repository.resolve(child.name, child.namespace_uri).nil?
          end

          # processContents="strict" on a wildcard demands the matched
          # child be declared; lax/skip place no declaration requirement.
          #
          # @return [void]
          def check_strict_wildcard_child(child, wildcard, collector,
                                          repository)
            return unless wildcard_process_mode(wildcard) == "strict"
            return if wildcard_child_declared?(child, repository)
            # xsi:type supplies the type definition itself — strict
            # assessment proceeds with it (addB116).
            return if xsi_attribute(child, "type")

            report_error(
              collector,
              code: "wildcard_undeclared_element",
              message: "Element '#{child.qualified_name}' matches " \
                       "xs:any with processContents=strict but is not " \
                       "declared",
              location: child.xpath,
              context: { element: child.qualified_name },
            )
          end

          # Collect particles from content model
          #
          # @param content_model [Lutaml::Xsd::Sequence, Lutaml::Xsd::Choice,
          #   Lutaml::Xsd::All]
          def collect_particles(content_model)
            # resolved_element_order preserves declaration order including
            # xs:any particles (which child_elements drops).
            ordered = content_model.resolved_element_order.to_a.select do |particle|
              PARTICLE_TYPES.any? { |t| particle.is_a?(t) }
            end
            return ordered if ordered.any?

            case content_model
            when Lutaml::Xsd::Sequence, Lutaml::Xsd::Choice
              Array(content_model.element) +
                Array(content_model.any) +
                Array(content_model.sequence) +
                Array(content_model.choice) +
                Array(content_model.group)
            when Lutaml::Xsd::All
              # xs:all holds bare elements only.
              Array(content_model.element)
            else
              []
            end
          end

          # Check if XML element matches schema particle
          #
          # @param xml_element [XmlElement] The XML element
          # @param particle [Object] The schema particle
          # @param repository [SchemaDefinitionResolver, nil]
          # @param parent [XmlElement, nil] Content-model owner, for
          #   wildcard namespace constraints scoped to the target namespace
          # @return [Boolean]
          def particle_matches?(xml_element, particle, repository = nil,
                                parent: nil, group_depth: 0, owner_ns: nil)
            particle_matches_child?(xml_element, particle, repository,
                                    parent: parent,
                                    group_depth: group_depth,
                                    owner_ns: owner_ns)
          end

          # Check if XML element matches schema element.
          #
          # A substitution-group member matches a reference to its head.
          #
          # @param xml_element [XmlElement] The XML element
          # @param schema_element [Lutaml::Xsd::Element] The schema element
          # @param repository [SchemaDefinitionResolver, nil]
          # @return [Boolean]
          def element_matches?(xml_element, schema_element, repository = nil,
                               owner_ns = nil)
            particle_matches_declaration?(xml_element, schema_element,
                                          repository, owner_ns) ||
              substitution_member?(xml_element, schema_element, repository)
          end

          # Whether the instance element's declaration is in the
          # substitution group headed by the particle's name/ref.
          #
          # @param xml_element [XmlElement]
          # @param particle [Lutaml::Xsd::Element]
          # @param repository [SchemaDefinitionResolver, nil]
          # @return [Boolean]
          def substitution_member?(xml_element, particle, repository)
            return false unless repository

            expected = particle.name || particle.ref
            return false if expected.to_s.empty?

            head_local = expected.to_s.split(":").last
            declaration = repository.resolve(
              xml_element.name, xml_element.namespace_uri
            )
            return false unless declaration

            head = repository.resolve(head_local, nil)
            return false unless head

            return false if substitution_blocked?(declaration, head,
                                                  head_local, repository)

            substitution_member_of?(declaration, head_local, repository)
          end

          # Get particle name for error messages
          #
          # @param particle [Object] The particle
          # @return [String]
          def particle_name(particle)
            if particle.is_a?(Lutaml::Xml::Schema::Xsd::Element)
              particle.name || particle.ref
            else
              particle.class.name.split("::").last
            end
          end

          # Containers have no instance name — naming them by class
          # ('Sequence') reads like a missing element declaration; the
          # group is the subject instead.
          #
          # @return [String]
          def display_particle_name(particle)
            return particle_name(particle) if
              particle.is_a?(Lutaml::Xml::Schema::Xsd::Element)

            "The model group"
          end

          # Whether the container's whole content can match the empty
          # sequence — every leaf particle optional.
          #
          # @return [Boolean]
          def container_matches_empty?(particle, repository)
            leaf_particles([particle], repository).all? do |leaf|
              parse_occurs(leaf.min_occurs, 1).zero?
            end
          end

          # Parse occurrence value
          #
          # @param value [String, Integer, nil] Occurrence value
          # @param default [Integer] Default value
          # @return [Integer]
          def parse_occurs(value, default)
            return default if value.nil? || value.to_s.empty?

            value.to_i
          end

          # Parse maximum occurrence value (handles "unbounded")
          #
          # @param value [String, Integer, nil] Max occurrence value
          # @param default [Integer] Default value
          # @return [Integer, Symbol]
          def parse_max_occurs(value, default)
            return default if value.nil? || value.to_s.empty?
            return :unbounded if value.to_s == "unbounded"

            value.to_i
          end
        end
      end
    end
  end
end
