# frozen_string_literal: true

module Lutaml
  module Xsd
    module Validation
      # Schema-side Unique Particle Attribution checking (XSD 1.0 §3.8.6).
      #
      # Reports content models where an instance element could match more
      # than one particle, making a valid document's interpretation
      # ambiguous:
      # - xs:choice: overlapping first-sets between alternatives
      # - xs:sequence: a nullable or repeatable particle followed by a
      #   particle matching the same first element
      # - element vs wildcard and wildcard vs wildcard overlaps at the
      #   same junctions
      #
      # First-sets are computed recursively over nested
      # sequence/choice/all containers; xs:group references are treated
      # as opaque (not descended) and contribute no names.
      #
      #     findings = UniqueParticleAttribution.new(schema).findings
      #     findings.each { |f| puts "#{f.code}: #{f.message}" }
      class UniqueParticleAttribution
        Finding = Struct.new(:code, :message, :path, keyword_init: true)

        FirstSet = Struct.new(:names, :wildcards, :nullable, :repeatable) do
          def merge(other)
            FirstSet.new(
              names | other.names,
              wildcards | other.wildcards,
              nullable || other.nullable,
            )
          end

          def overlaps?(other)
            names.intersect?(other.names) ||
              wildcards.any? { |w| other.wildcards.any? { |o| wildcard_overlap?(w, o) } } ||
              wildcards.any? { |w| other.names.any? { |name| wildcard_admits?(w, name) } } ||
              other.wildcards.any? { |w| names.any? { |name| wildcard_admits?(w, name) } }
          end

          private

          # Conservative wildcard-pair overlap: ##any overlaps everything;
          # distinct constraints are treated as overlapping only when
          # identical (##local, ##other, lists, single namespaces).
          def wildcard_overlap?(left, right)
            left == right || left == "##any" || right == "##any"
          end

          def wildcard_admits?(wildcard, (namespace, _name))
            case wildcard
            when "##any", "" then true
            when "##local" then namespace.empty?
            when "##other" then !namespace.empty?
            when "##targetNamespace" then false
            else wildcard.split(/\s+/).include?(namespace)
            end
          end
        end

        EMPTY_FIRST = FirstSet.new([].freeze, [].freeze, true).freeze

        # @param schema [Lutaml::Xml::Schema::Xsd::Schema] parsed schema
        def initialize(schema)
          @schema = schema
          @seen = {}.compare_by_identity
          @groups = {}
          Array(@schema.group).each do |group|
            @groups[group.name.to_s] = group if group.name
          end
          @substitutes = {}
          Array(@schema.element).each do |element|
            next unless element.name && element.substitution_group.to_s.match?(/\S/)

            head = element.substitution_group.to_s.split(":").last
            (@substitutes[head] ||= []) << element
          end
        end

        # @return [Array<Finding>] UPA violations, empty when deterministic
        def findings
          compute! unless @computed
          @findings
        end

        private

        def compute!
          @findings = []
          Array(@schema.element).each do |element|
            check_type(element.complex_type, "/#{element.name}") if
              element.complex_type
          end
          Array(@schema.complex_type).each do |complex_type|
            check_type(complex_type, complex_type.name.to_s)
          end
          @computed = true
        end

        def check_type(type, path)
          return unless type.is_a?(Lutaml::Xml::Schema::Xsd::ComplexType)

          container = type.sequence || type.choice || type.all
          check_container(container, path) if container
        end

        # Walks a container: checks its own junctions, then descends.
        def check_container(container, path)
          return unless container
          return if @seen[container]

          @seen[container] = true

          particles = ordered_particles(container)
          check_junctions(particles, container, path)
          particles.each do |particle|
            case particle
            when Lutaml::Xsd::Sequence, Lutaml::Xsd::Choice, Lutaml::Xsd::All
              check_container(particle, "#{path}/#{particle_name(particle)}")
            end
          end
        end

        def check_junctions(particles, container, path)
          firsts = particles.map { |p| first_set(p) }

          if container.is_a?(Lutaml::Xsd::Choice)
            check_choice_overlap(particles, firsts, path)
          else
            check_sequence_junctions(particles, firsts, path)
          end
        end

        def check_choice_overlap(particles, firsts, path)
          firsts.each_with_index do |first, i|
            firsts[(i + 1)..].each_with_index do |other, j|
              next unless first.overlaps?(other)

              report(
                path,
                "ambiguous choice: '#{particle_name(particles[i])}' and " \
                "'#{particle_name(particles[i + 1 + j])}' can match the " \
                "same element",
              )
            end
          end
        end

        def check_sequence_junctions(particles, firsts, path)
          firsts.each_with_index do |first, i|
            next if i.zero?

            previous = firsts[i - 1]
            next unless previous.nullable || previous.repeatable
            next unless first.overlaps?(previous)

            report(
              path,
              "ambiguous sequence: '#{particle_name(particles[i - 1])}' " \
              "can be followed by '#{particle_name(particles[i])}' — both " \
              "match the same first element",
            )
          end
        end

        def report(path, message)
          @findings << Finding.new(
            code: "upa_violation",
            message: message,
            path: path,
          )
        end

        # First-set of a particle: the element names and wildcards it can
        # match first, and whether it can be absent. Repeatable marks
        # particles whose occurrence permits more than one match.
        def first_set(particle)
          case particle
          when Lutaml::Xml::Schema::Xsd::Element
            FirstSet.new(element_keys(particle), [].freeze,
                         parse_min(particle).zero?).tap do |first|
              first.repeatable = parse_max(particle) != 1
            end
          when Lutaml::Xsd::Any
            FirstSet.new([].freeze, [wildcard_spec(particle)].compact,
                         parse_min(particle).zero?).tap do |first|
              first.repeatable = parse_max(particle) != 1
            end
          when Lutaml::Xsd::Sequence
            apply_occurrence(sequence_first(particle), particle)
          when Lutaml::Xsd::Choice, Lutaml::Xsd::All
            apply_occurrence(choice_first(particle), particle)
          else
            EMPTY_FIRST
          end
        end

        # A container particle's own occurrence widens its computed
        # first-set: minOccurs="0" makes it nullable, max≠1 repeatable.
        def apply_occurrence(first, particle)
          first.nullable ||= parse_min(particle).zero?
          first.repeatable ||= parse_max(particle) != 1
          first
        end

        # Leading names until the first required, exactly-once particle;
        # nullable only when every particle can be absent.
        def sequence_first(sequence)
          names = []
          wildcards = []
          nullable = true
          repeatable = false
          ordered_particles(sequence).each do |particle|
            first = first_set(particle)
            names |= first.names
            wildcards |= first.wildcards
            repeatable ||= first.repeatable
            unless first.nullable
              nullable = false
              break
            end
          end
          FirstSet.new(names, wildcards, nullable).tap do |first|
            first.repeatable = repeatable
          end
        end

        def choice_first(choice)
          names = []
          wildcards = []
          nullable = false
          repeatable = false
          ordered_particles(choice).each do |particle|
            first = first_set(particle)
            names |= first.names
            wildcards |= first.wildcards
            nullable ||= first.nullable
            repeatable ||= first.repeatable
          end
          FirstSet.new(names, wildcards, nullable).tap do |first|
            first.repeatable = repeatable
          end
        end

        # Particles in declaration order — resolved_element_order preserves
        # the source sequence including xs:any, which attribute-style
        # accessor reads would reorder. xs:group references expand to the
        # referenced declaration's particles (cycle-guarded per chain).
        def ordered_particles(container, group_chain = {})
          ordered = container.resolved_element_order
          raw = if ordered.to_a.any?
                  ordered.to_a
                else
                  case container
                  when Lutaml::Xml::Schema::Xsd::Sequence,
                       Lutaml::Xml::Schema::Xsd::Choice
                    %i[element any sequence choice].flat_map do |kind|
                      Array(container.public_send(kind))
                    end.compact
                  when Lutaml::Xml::Schema::Xsd::All
                    Array(container.element).compact
                  else
                    []
                  end
                end
          raw.flat_map do |particle|
            if particle.is_a?(Lutaml::Xml::Schema::Xsd::Group)
              expand_group(particle, group_chain)
            else
              [particle]
            end
          end
        end

        def expand_group(group_ref, chain)
          local = (group_ref.ref || group_ref.name).to_s.split(":").last
          declaration = @groups[local]
          return [] unless declaration
          return [] if chain[local]

          chain[local] = true
          ordered_particles(declaration, chain)
        end

        # An element particle matches its own name plus every member of
        # the substitution group headed by it.
        def element_keys(element)
          own = element_key(element)
          return [] unless own

          members = @substitutes.fetch(own[1], [])
          [own] + members.filter_map do |member|
            member.name ? [@schema.target_namespace.to_s, member.name] : nil
          end
        end

        def element_key(element)
          name = element.name || element.ref
          return nil if name.to_s.empty?

          namespace = if element.name
                        element.target_namespace.to_s
                      else
                        @schema.target_namespace.to_s
                      end
          [namespace, name.to_s]
        end

        def wildcard_spec(any_particle)
          any_particle.namespace.to_s
        end

        def parse_min(particle)
          value = particle.min_occurs.to_s
          value.empty? ? 1 : value.to_i
        rescue StandardError
          1
        end

        def parse_max(particle)
          value = particle.max_occurs.to_s
          return Float::INFINITY if value == "unbounded"
          return 1 if value.empty?

          value.to_i
        rescue StandardError
          1
        end

        def particle_name(particle)
          case particle
          when Lutaml::Xml::Schema::Xsd::Element
            particle.name || particle.ref || "element"
          when Lutaml::Xsd::Any then "any"
          when Lutaml::Xsd::Choice then "choice"
          when Lutaml::Xsd::Sequence then "sequence"
          when Lutaml::Xsd::All then "all"
          else particle.class.name.split("::").last
          end
        end
      end
    end
  end
end
