# frozen_string_literal: true

require_relative "../validation_rule"

module Lutaml
  module Xsd
    module Validation
      module Rules
        # OccurrenceValidationRule validates occurrence constraints
        #
        # This rule checks:
        # - minOccurs constraint is satisfied
        # - maxOccurs constraint is satisfied (including unbounded)
        # - Element occurrence counts
        # - Reports violations with expected vs actual counts
        #
        # Based on Jing validator occurrence validation algorithm.
        #
        # @example Using the rule
        #   rule = OccurrenceValidationRule.new
        #   rule.validate(parent_element, schema_particle, collector)
        #
        # @see docs/JING_ALGORITHM_PORTING_GUIDE.md Occurrence Validation
        class OccurrenceValidationRule < ValidationRule
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
            "Validates minOccurs and maxOccurs constraints on elements"
          end

          # Validate occurrence constraints
          #
          # Validates that elements appear the correct number of times
          # according to their minOccurs and maxOccurs constraints.
          #
          # @param parent_element [XmlElement] The parent XML element
          # @param schema_particle [Lutaml::Xsd::Element, Lutaml::Xsd::Sequence,
          #   Lutaml::Xsd::Choice, Lutaml::Xsd::All] The schema particle
          # @param collector [ResultCollector] Collector for validation results
          # @return [void]
          def validate(parent_element, schema_particle, collector,
                       repository: nil)
            return unless schema_particle
            return unless parent_element

            # A nilled element has no content to count (QFE1700g2).
            declaration = repository&.resolve(
              parent_element.name, parent_element.namespace_uri
            )
            return if declaration &&
              nilled_instance?(parent_element, declaration)

            wildcards = collect_wildcards(schema_particle, repository)
            name_counts = collect_declared_names(schema_particle,
                                                 repository).tally

            # Handle different particle types
            case schema_particle
            when Lutaml::Xsd::Element
              validate_element_occurrence(parent_element, schema_particle,
                                          collector, repository: repository,
                                                     wildcards: wildcards,
                                                     name_counts: name_counts)
            when Lutaml::Xsd::Sequence
              validate_sequence_occurrences(parent_element, schema_particle,
                                            collector, repository: repository,
                                                       wildcards: wildcards,
                                                       name_counts: name_counts)
            when Lutaml::Xsd::Choice
              validate_choice_occurrences(parent_element, schema_particle,
                                          collector, repository: repository)
            when Lutaml::Xsd::All
              validate_all_occurrences(parent_element, schema_particle,
                                       collector, repository: repository,
                                                  wildcards: wildcards,
                                                  name_counts: name_counts)
            when Lutaml::Xml::Schema::Xsd::Group
              # The group REF carries the occurrence bounds; the expanded
              # declaration itself has none.
              expand_group_container(schema_particle, repository).each do |container|
                validate_container_occurrences(
                  parent_element, container, collector,
                  repository: repository,
                  min_occurs: parse_occurs(schema_particle.min_occurs, 1),
                  max_occurs: parse_max_occurs(schema_particle.max_occurs, 1),
                  wildcards: collect_wildcards(container, repository),
                  name_counts: collect_declared_names(container,
                                                      repository).tally
                )
              end
            end
          end

          # This rule validates the element's children against the
          # content-model particle of the element's type.
          #
          # @param schema_def [Object, nil] Resolved schema declaration
          # @param repository [SchemaDefinitionResolver, nil]
          # @return [Object, nil]
          def schema_argument(schema_def, repository: nil)
            return nil unless schema_def && repository

            repository.content_model_for(schema_def)
          end

          private

          # Validate element occurrence
          #
          # @param parent_element [XmlElement] Parent element
          # @param schema_element [Lutaml::Xsd::Element] Schema element
          # @param collector [ResultCollector] Result collector
          # @return [void]
          def validate_element_occurrence(parent_element, schema_element,
                                          collector, repository: nil,
                                          wildcards: [], name_counts: nil,
                                          container_min: 1)
            min_occurs = parse_occurs(schema_element.min_occurs, 1)
            max_occurs = parse_max_occurs(schema_element.max_occurs, 1)

            # Count actual occurrences
            actual_count = count_element_occurrences(
              parent_element, schema_element, repository
            )

            # A wildcard in the same content model can absorb the same
            # named children this declaration counts, and same-named
            # sibling declarations each count every same-named child —
            # per-name counts cannot attribute occurrences in either
            # case; abstain (addB135, memberType004).
            return if wildcard_absorbs_counts?(parent_element, wildcards,
                                               schema_element, repository)
            return if ambiguous_declared_name?(schema_element, name_counts)

            # Check minimum occurrence
            unless container_min.zero?
              validate_min_occurs(parent_element, schema_element,
                                  actual_count, min_occurs, collector)
            end

            # Check maximum occurrence
            validate_max_occurs(parent_element, schema_element, actual_count,
                                max_occurs, collector)
          end

          # Validate sequence particle occurrences
          #
          # @param parent_element [XmlElement] Parent element
          # @param sequence [Lutaml::Xsd::Sequence] Schema sequence
          # @param collector [ResultCollector] Result collector
          # @return [void]
          def validate_container_occurrences(parent_element, container,
                                             collector, repository:,
                                             min_occurs:, max_occurs:,
                                             wildcards: [], name_counts: {})
            case container
            when Lutaml::Xsd::Sequence
              validate_sequence_occurrences(parent_element, container,
                                            collector, repository: repository,
                                                       min_occurs: min_occurs,
                                                       max_occurs: max_occurs,
                                                       wildcards: wildcards,
                                                       name_counts: name_counts)
            when Lutaml::Xsd::Choice
              validate_choice_occurrences(parent_element, container,
                                          collector, repository: repository,
                                                     min_occurs: min_occurs,
                                                     max_occurs: max_occurs)
            when Lutaml::Xsd::All
              validate_all_occurrences(parent_element, container, collector,
                                       repository: repository,
                                       min_occurs: min_occurs,
                                       max_occurs: max_occurs,
                                       wildcards: wildcards,
                                       name_counts: name_counts)
            end
          end

          def validate_sequence_occurrences(parent_element, sequence,
                                            collector, repository: nil,
                                            min_occurs: nil, max_occurs: nil,
                                            wildcards: [], name_counts: {})
            return if sequence.element.empty?
            # A container that may occur zero times voids its inner
            # requirements (mgG012: sequence(e1) maxOccurs="0", empty doc
            # is valid). maxOccurs="unbounded" parses to a Symbol — the
            # zero test only applies to integers.
            return if max_occurs.nil? &&
              parse_max_occurs(sequence.max_occurs, 1).is_a?(Integer) &&
              parse_max_occurs(sequence.max_occurs, 1).zero?

            # Group-ref bounds: the sequence repeats as a UNIT, so the
            # children are matched against the element list cyclically
            # and the completed iteration count is checked against the
            # ref's bounds. The sequence's OWN bounds get the same
            # treatment when it repeats (V003: sequence{2,4}(e1,e2)
            # legitimately carries two e1s).
            if min_occurs || max_occurs
              validate_sequence_unit_iterations(parent_element, sequence,
                                                collector, repository,
                                                min_occurs || 0, max_occurs)
              return
            end
            if parse_max_occurs(sequence.max_occurs, 1) != 1
              validate_sequence_unit_iterations(
                parent_element, sequence, collector, repository,
                parse_occurs(sequence.min_occurs, 1),
                parse_max_occurs(sequence.max_occurs, 1)
              )
              return
            end

            Array(sequence.element).each do |element|
              validate_element_occurrence(parent_element, element, collector,
                                          repository: repository,
                                          wildcards: wildcards,
                                          name_counts: name_counts,
                                          container_min:
                                            parse_occurs(sequence.min_occurs,
                                                         1))
            end

            # Nested particles are deliberately not recursed into: their
            # children interleave by position, which per-element counts
            # cannot see — a repeated inner sequence's elements
            # legitimately exceed their own maxOccurs across iterations
            # (Q003/V003). Structural exactness for nested bounds is the
            # content rule's NFA matcher verdict.
          end

          # Greedy scan of the children against the sequence's element
          # list; returns the number of COMPLETED iterations, or nil when
          # the scan cannot decide. Children fill the candidate at the
          # current position up to its maxOccurs, then advance past it;
          # optional candidates are skipped when a child cannot fill
          # them. An unplaceable child or a non-empty trailing partial
          # iteration leaves the iteration split ambiguous — a different
          # split may still satisfy the bounds (addB176:
          # sequence{2}(a1..2, b0..1) matches a,a,b as {a} {a,b}) — so
          # the count is indeterminate and the caller must abstain.
          #
          # @return [Integer, nil]
          def count_sequence_iterations(parent_element, sequence, repository)
            elements = Array(sequence.element)
            return 0 if elements.empty?

            position = 0
            consumed = Array.new(elements.size, 0)
            iterations = 0
            parent_element.children.each do |child|
              position, placed = place_child(child, elements, position,
                                             consumed, repository)
              return nil unless placed

              consumed[position] += 1
              position += 1
              next unless position == elements.size

              iterations += 1
              position = 0
              consumed.fill(0)
            end
            return nil unless position.zero?

            iterations
          end

          # Advance the iteration position so one child can be consumed;
          # placed=false when the child matches no reachable candidate.
          #
          # @return [Array(Integer, Boolean)]
          def place_child(child, elements, position, consumed, repository)
            while position < elements.size
              candidate = elements[position]
              if child_matches_particle?(child, candidate, repository)
                max = parse_max_occurs(candidate.max_occurs, 1)
                return position, true if max == :unbounded ||
                  consumed[position] < max
              elsif parse_occurs(candidate.min_occurs, 1) != 0
                return position, false
              end
              position += 1
            end
            [position, false]
          end

          def child_matches_particle?(child, candidate, repository)
            particle_matches_declaration?(child, candidate, repository) ||
              substitution_member?(child, candidate, repository)
          end

          # Whether a wildcard in the same content model can absorb a
          # child this declaration's count would claim — the per-name
          # count then over-attributes occurrences (addB135).
          #
          # @return [Boolean]
          def wildcard_absorbs_counts?(parent_element, wildcards,
                                       schema_element, repository)
            return false if wildcards.empty?

            parent_element.children.any? do |child|
              next false unless
                child_matches_particle?(child, schema_element, repository)

              wildcards.any? do |wildcard|
                wildcard_permits?(wildcard, parent_element, child,
                                  repository)
              end
            end
          end

          # Whether another declaration in the same content model shares
          # this declaration's local name — every same-named child is
          # then counted against both, so per-name bounds cannot decide.
          #
          # @return [Boolean]
          def ambiguous_declared_name?(schema_element, name_counts)
            return false if name_counts.nil? || name_counts.empty?

            local = declared_local_name(schema_element)
            return false if local.nil?

            name_counts[local].to_i > 1
          end

          # @return [String, nil]
          def declared_local_name(particle)
            local = (particle.name || particle.ref).to_s.split(":").last
            local.nil? || local.empty? ? nil : local
          end

          # Local names declared by element particles across the content
          # model, group refs expanded.
          #
          # @return [Array<String>]
          def collect_declared_names(particle, repository, depth = 0)
            case particle
            when Lutaml::Xsd::Element, Lutaml::Xml::Schema::Xsd::Element
              local = declared_local_name(particle)
              local ? [local] : []
            when Lutaml::Xml::Schema::Xsd::Group
              return [] if depth > 8

              expand_group_container(particle, repository).flat_map do |container|
                collect_declared_names(container, repository, depth + 1)
              end
            else
              return [] if depth > 8

              accessors = PARTICLE_CHILD_ACCESSORS.find do |klass, _|
                particle.is_a?(klass)
              end&.last
              return [] unless accessors

              accessors.flat_map do |accessor|
                Array(particle.public_send(accessor)).flat_map do |child|
                  collect_declared_names(child, repository, depth + 1)
                end
              end
            end
          end

          # @return [void]
          def validate_sequence_unit_iterations(parent_element, sequence,
                                                collector, repository,
                                                min_occurs, max_occurs)
            iterations = count_sequence_iterations(parent_element, sequence,
                                                   repository)
            # The greedy scan cannot split the children into iterations —
            # abstain rather than report a false violation.
            return if iterations.nil?

            return if iterations >= min_occurs &&
              (max_occurs == :unbounded || iterations <= max_occurs)

            report_error(
              collector,
              code: if iterations < min_occurs
                      "min_occurs_violation"
                    else
                      "max_occurs_violation"
                    end,
              message: "The model group must occur " \
                       "#{iterations < min_occurs ? 'at least' : 'at most'} " \
                       "#{iterations < min_occurs ? min_occurs : max_occurs} " \
                       "time(s), found #{iterations}",
              location: parent_element.xpath,
              context: { min_occurs: min_occurs, max_occurs: max_occurs,
                         actual: iterations },
            )
          end

          # Validate choice particle occurrences
          #
          # @param parent_element [XmlElement] Parent element
          # @param choice [Lutaml::Xsd::Choice] Schema choice
          # @param collector [ResultCollector] Result collector
          # @return [void]
          def validate_choice_occurrences(parent_element, choice, collector,
                                          repository: nil, min_occurs: nil,
                                          max_occurs: nil)
            min_occurs ||= parse_occurs(choice.min_occurs, 1)
            max_occurs ||= parse_max_occurs(choice.max_occurs, 1)
            return if max_occurs.is_a?(Integer) && max_occurs.zero?

            present_count = count_choice_alternatives(parent_element, choice,
                                                      repository)
            occurrence_count = choice_occurrence_count(present_count, choice, repository)

            if occurrence_count < min_occurs
              report_error(
                collector,
                code: "choice_min_occurs_violation",
                message: "Choice must have at least #{min_occurs} " \
                         "alternative(s), found #{occurrence_count}",
                location: parent_element.xpath,
                context: {
                  min_occurs: min_occurs,
                  actual: occurrence_count,
                },
              )
            end

            return unless max_occurs != :unbounded &&
              occurrence_count > max_occurs

            report_error(
              collector,
              code: "choice_max_occurs_violation",
              message: "Choice must have at most #{max_occurs} " \
                       "alternative(s), found #{occurrence_count}",
              location: parent_element.xpath,
              context: {
                max_occurs: max_occurs,
                actual: occurrence_count,
              },
            )
          end

          # One choice occurrence consumes one alternative branch, where
          # the branch particle repeats per its own occurrence bounds —
          # a wildcard with 4..6 absorbs four children in a single
          # choice occurrence. Matched children beyond one branch's
          # capacity imply repeated choice occurrences.
          #
          # @return [Integer]
          def choice_occurrence_count(present_count, choice, repository)
            if present_count.zero?
              # A choice whose every alternative is optional matches the
              # empty sequence and occurs trivially.
              return 1 if choice_alternatives(choice).all? do |alt|
                parse_occurs(alt.min_occurs, 1).zero?
              end

              return 0
            end

            capacities = choice_alternatives(choice).map do |alt|
              branch_capacity(alt, repository, 0)
            end
            return 1 if capacities.empty?
            return 1 if capacities.include?(:unbounded)
            return 1 if capacities.max >= present_count

            present_count
          end

          # Children one branch iteration can absorb: a branch repeats
          # per its own maxOccurs, and composite branches (group refs,
          # sequences, nested choices) multiply or combine with their
          # contents' capacities — a sequence adds them, a choice takes
          # the largest.
          #
          # @return [Integer, Symbol]
          def branch_capacity(particle, repository, depth)
            return :unbounded if depth > 5

            own = parse_max_occurs(particle.max_occurs, 1)
            return own unless composite_particle?(particle)
            return :unbounded if own == :unbounded

            inner_cap = composite_capacity(particle, repository, depth)
            return :unbounded if inner_cap == :unbounded

            multiplier = own.zero? ? 1 : own
            multiplier * [inner_cap, 1].max
          end

          def composite_particle?(particle)
            particle.is_a?(Lutaml::Xml::Schema::Xsd::Group) ||
              particle.is_a?(Lutaml::Xsd::Sequence) ||
              particle.is_a?(Lutaml::Xsd::Choice)
          end

          def composite_capacity(particle, repository, depth)
            # The CONTAINER's kind decides aggregation: a group whose
            # declaration is a sequence ADDS its members' capacities, a
            # choice takes the largest — deciding from the ref particle
            # itself always maxed (groupH class).
            children, aggregate =
              if particle.is_a?(Lutaml::Xml::Schema::Xsd::Group)
                container = expand_group_container(particle,
                                                   repository).first
                if container
                  [choice_alternatives(container),
                   container_choice?(container) ? :max : :sum]
                else
                  [[], :max]
                end
              else
                [choice_alternatives(particle),
                 particle.is_a?(Lutaml::Xsd::Sequence) ? :sum : :max]
              end
            caps = children.map do |child|
              branch_capacity(child, repository, depth + 1)
            end
            return :unbounded if caps.include?(:unbounded)

            aggregate == :sum ? caps.sum : (caps.max || 0)
          end

          # @return [Boolean]
          def container_choice?(container)
            container.is_a?(Lutaml::Xsd::Choice) ||
              container.is_a?(Lutaml::Xml::Schema::Xsd::Choice)
          end

          # Choice alternatives are particles of any kind.
          #
          # @return [Array]
          def choice_alternatives(choice)
            Array(choice.element) + Array(choice.any) +
              Array(choice.sequence) + Array(choice.choice) +
              Array(choice.group)
          end

          # Validate all particle occurrences
          #
          # @param parent_element [XmlElement] Parent element
          # @param all [Lutaml::Xsd::All] Schema all
          # @param collector [ResultCollector] Result collector
          # @return [void]
          def validate_all_occurrences(parent_element, all, collector,
                                       repository: nil, min_occurs: nil,
                                       max_occurs: nil, wildcards: [],
                                       name_counts: {})
            return if all.element.empty?

            all_max = max_occurs || parse_max_occurs(all.max_occurs, 1)
            return if all_max.is_a?(Integer) && all_max.zero?

            # The all or its group ref being optional voids the member
            # minimums.
            container_min = [min_occurs, parse_occurs(all.min_occurs, 1)]
              .compact.min

            # In xs:all, each element can appear 0 or 1 times
            # (or based on its minOccurs/maxOccurs)
            Array(all.element).each do |element|
              validate_element_occurrence(parent_element, element, collector,
                                          repository: repository,
                                          wildcards: wildcards,
                                          name_counts: name_counts,
                                          container_min: container_min)
            end
          end

          # Count element occurrences in parent
          #
          # @param parent_element [XmlElement] Parent element
          # @param schema_element [Lutaml::Xsd::Element] Schema element
          # @return [Integer]
          def count_element_occurrences(parent_element, schema_element,
                                        repository = nil)
            parent_element.children.count do |child|
              particle_matches_declaration?(child, schema_element,
                                            repository) ||
                substitution_member?(child, schema_element, repository)
            end
          end

          # Whether the child's declaration is a member of the
          # substitution group headed by the particle's name/ref.
          #
          # @return [Boolean]
          def substitution_member?(child, schema_element, repository)
            return false unless repository

            head = schema_element.ref || schema_element.name
            return false if head.to_s.empty?

            head_local = head.to_s.split(":").last
            declaration = repository.resolve(child.name, child.namespace_uri)
            return false unless declaration

            resolved_head = repository.resolve(head_local, nil)
            return false unless resolved_head

            return false if substitution_blocked?(declaration, resolved_head,
                                                  head_local, repository)

            substitution_member_of?(declaration, head_local, repository)
          end

          # Count how many choice alternatives are present
          #
          # @param parent_element [XmlElement] Parent element
          # @param choice [Lutaml::Xsd::Choice] Schema choice
          # @return [Integer]
          def count_choice_alternatives(parent_element, choice,
                                        repository = nil)
            alternatives = choice_alternatives(choice)
            return 0 if alternatives.empty? || parent_element.children.empty?

            # Count instance elements that matched the choice — a single
            # child matching several identical alternatives counts once.
            parent_element.children.count do |child|
              alternatives.any? do |alt_element|
                if alt_element.is_a?(Lutaml::Xml::Schema::Xsd::Any)
                  wildcard_permits?(alt_element, parent_element, child,
                                    repository)
                else
                  particle_matches_child?(child, alt_element, repository,
                                          parent: parent_element)
                end
              end
            end
          end

          # Whether one instance child matches one alternative declaration.
          # Validate minimum occurrence constraint
          #
          # @param parent_element [XmlElement] Parent element
          # @param schema_element [Lutaml::Xsd::Element] Schema element
          # @param actual_count [Integer] Actual count
          # @param min_occurs [Integer] Minimum occurrences
          # @param collector [ResultCollector] Result collector
          # @return [void]
          def validate_min_occurs(parent_element, schema_element, actual_count,
                                  min_occurs, collector)
            return if actual_count >= min_occurs

            name = schema_element.name.to_s
            display_name = if name.match?(/\S/)
                             name
                           else
                             "ref:#{schema_element.ref}"
                           end
            report_error(
              collector,
              code: "min_occurs_violation",
              message: "Element '#{display_name}' must occur at " \
                       "least #{min_occurs} time(s), found #{actual_count}",
              location: parent_element.xpath,
              context: {
                element: display_name,
                min_occurs: min_occurs,
                actual: actual_count,
              },
              suggestion: build_min_occurs_suggestion(schema_element,
                                                      min_occurs, actual_count),
            )
          end

          # Validate maximum occurrence constraint
          #
          # @param parent_element [XmlElement] Parent element
          # @param schema_element [Lutaml::Xsd::Element] Schema element
          # @param actual_count [Integer] Actual count
          # @param max_occurs [Integer, Symbol] Maximum occurrences
          # @param collector [ResultCollector] Result collector
          # @return [void]
          def validate_max_occurs(parent_element, schema_element, actual_count,
                                  max_occurs, collector)
            return if max_occurs == :unbounded
            return if actual_count <= max_occurs

            report_error(
              collector,
              code: "max_occurs_violation",
              message: "Element '#{schema_element.name}' must occur at " \
                       "most #{max_occurs} time(s), found #{actual_count}",
              location: parent_element.xpath,
              context: {
                element: schema_element.name,
                max_occurs: max_occurs,
                actual: actual_count,
              },
              suggestion: "Remove #{actual_count - max_occurs} " \
                          "occurrence(s) of '#{schema_element.name}'",
            )
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

          # Build suggestion for min occurs violation
          #
          # @param schema_element [Lutaml::Xsd::Element] Schema element
          # @param min_occurs [Integer] Minimum occurrences
          # @param actual_count [Integer] Actual count
          # @return [String]
          def build_min_occurs_suggestion(schema_element, min_occurs,
                                          actual_count)
            missing = min_occurs - actual_count
            if missing == 1
              "Add 1 occurrence of element '#{schema_element.name}'"
            else
              "Add #{missing} occurrences of element '#{schema_element.name}'"
            end
          end
        end
      end
    end
  end
end
