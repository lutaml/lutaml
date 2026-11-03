# frozen_string_literal: true

module Lutaml
  module Xsd
    module Validation
      # Guards the native engine against occurrence-product blowups.
      #
      # A content model like `element unbounded inside sequence{100}`
      # makes the engine's compiled automaton large enough that the
      # process gets killed (W3C particlesZ034_b). The guard walks the
      # particle tree, takes the largest product of maxOccurs along any
      # root-to-leaf path, and flags models past the cap — those are
      # decided by the Ruby pipeline alone.
      #
      # Group refs expand through the supplied expander when available;
      # an unresolvable ref counts as the unbounded proxy (conservative:
      # the engine stays off for that model).
      class OccurrenceProductGuard
        CAP = 1_000_000
        UNBOUNDED_PROXY = 65_536
        MAX_DEPTH = 8

        # Member accessors differ per model class (a ComplexType has no
        # .element; an All has only .element).
        MEMBER_KINDS = {
          Lutaml::Xml::Schema::Xsd::ComplexType => %i[sequence choice all
                                                      group],
          Lutaml::Xsd::Sequence => %i[element any sequence choice group],
          Lutaml::Xsd::Choice => %i[element any sequence choice group],
          Lutaml::Xsd::All => %i[element],
        }.freeze

        # A guard over a schema: named complexTypes indexed by local
        # name, plus the model accessor shared by types and containers.
        def self.for_schema(schema, group_expander: nil)
          named = (Array(schema.complex_type) +
                   Array(schema.element).filter_map(&:complex_type))
            .to_h { |t| [t.name.to_s, t] }
          new(
            named_types: named,
            group_expander: group_expander,
            container_particles: lambda { |container|
              kinds = MEMBER_KINDS.find { |klass, _| container.is_a?(klass) }
              member_kinds = if kinds
                               kinds[1]
                             else
                               %i[element any sequence
                                  choice group]
                             end
              member_kinds.flat_map do |kind|
                Array(container.public_send(kind)).compact
              end
            },
          )
        end

        def initialize(named_types: {}, group_expander: nil,
                       container_particles: nil)
          @named_types = named_types
          @group_expander = group_expander
          @container_particles = container_particles
        end

        def particles_safe?(particles)
          particles.all? { |particle| product(particle, 1, 0) <= CAP }
        end

        # Walks a type's content model. Nested elements referencing
        # named types are covered when those types are reachable from
        # the schema walk (schema_safe?); a named type reachable ONLY
        # through a nested type= reference is out of this walk's reach
        # and degrades to its element product alone.
        def type_safe?(type, seen = {}.compare_by_identity)
          return true if type.nil? || seen.key?(type)
          return false unless type_resolvable?(type)

          seen[type] = true
          @container_particles.call(type).all? do |particle|
            if group_ref?(particle)
              expanded = @group_expander&.call(particle)
              expanded && particles_safe?(expanded)
            else
              product(particle, 1, 0) <= CAP
            end
          end
        end

        # Entry points of a schema: every top-level element's effective
        # type plus every global complexType.
        def schema_safe?(schema)
          entries = Array(schema.complex_type) +
            Array(schema.element).filter_map do |element|
              local = element.type.to_s.split(":").last
              if element.complex_type
                element.complex_type
              elsif local && @named_types.key?(local)
                @named_types[local]
              end
            end
          seen = {}.compare_by_identity
          entries.all? { |type| type_safe?(type, seen) }
        end

        def product(particle, acc, depth)
          return acc if depth > MAX_DEPTH
          return acc * UNBOUNDED_PROXY if unsafe_ref?(particle)

          own = max_occurs(particle)
          step = own == :unbounded ? UNBOUNDED_PROXY : own
          acc *= [step, 1].max
          return acc if acc > CAP

          child_particles(particle).each do |child|
            acc = product(child, acc, depth + 1)
            return acc if acc > CAP
          end
          acc
        end

        private

        def max_occurs(particle)
          value = particle.max_occurs
          return 1 if value.nil? || value.to_s.empty?
          return :unbounded if value.to_s == "unbounded"

          value.to_i
        end

        def unsafe_ref?(particle)
          particle == :unsafe_ref
        end

        def type_resolvable?(type)
          type.is_a?(Lutaml::Xml::Schema::Xsd::ComplexType) ||
            type.is_a?(Lutaml::Xsd::Sequence) ||
            type.is_a?(Lutaml::Xsd::Choice) ||
            type.is_a?(Lutaml::Xsd::All)
        end

        def child_particles(particle)
          if group_ref?(particle)
            expanded = @group_expander ? @group_expander.call(particle) : []
            return expanded unless expanded.empty?

            # Unresolvable ref: unknown contents count as unbounded.
            return [:unsafe_ref]
          end
          return [] unless container?(particle)

          @container_particles&.call(particle) || []
        end

        def group_ref?(particle)
          particle.is_a?(Lutaml::Xml::Schema::Xsd::Group)
        end

        def container?(particle)
          particle.is_a?(Lutaml::Xsd::Sequence) ||
            particle.is_a?(Lutaml::Xsd::Choice) ||
            particle.is_a?(Lutaml::Xsd::All)
        end
      end
    end
  end
end
