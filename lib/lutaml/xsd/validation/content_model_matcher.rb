# frozen_string_literal: true

module Lutaml
  module Xsd
    module Validation
      # NFA-based content model matching.
      #
      # The greedy particle walk mis-validates interleaved repeats and
      # bounded container groups (a container run is truncated by child
      # count, not iteration count). This matcher compiles the particle
      # tree into a nondeterministic automaton — occurrence constraints
      # become graph structure — and simulates it over the child list,
      # so membership is decided exactly.
      #
      # xs:all compiles to a subset automaton over its members (XSD 1.0
      # bounds every member to 0..1, so a bitmask of satisfied members is
      # a complete state space).
      #
      # Matching predicates are injected as callables, keeping the
      # automaton free of rule knowledge:
      # - element_match:      (child, element_particle) → bool
      # - wildcard_match:     (child, wildcard_particle) → bool
      # - container_particles: (sequence/choice/all) → ordered particles
      # - group_particles:    (group ref) → expanded container list
      class ContentModelMatcher
        Result = Struct.new(:matched, :fail_index, :fail_reason,
                            keyword_init: true)

        UNBOUNDED = :unbounded

        # Bounded occurrence ranges beyond MAX_UNROLL compile as loops
        # (unrolling maxOccurs="1000" explodes the automaton; the
        # occurrence rule keeps the exact count). xs:all member counts
        # beyond MAX_ALL_MEMBERS fall back to a permissive unordered
        # loop — 2^n states is otherwise explosive.
        MAX_UNROLL = 16
        MAX_ALL_MEMBERS = 12

        def initialize(particles, element_match:, wildcard_match:,
                       container_particles:, group_particles:)
          @element_match = element_match
          @wildcard_match = wildcard_match
          @container_particles = container_particles
          @group_particles = group_particles
          @transitions = Hash.new { |h, k| h[k] = [] }
          @epsilons = Hash.new { |h, k| h[k] = [] }
          @accepting = []
          @memo = Hash.new do |memo, particle|
            inner = {}.compare_by_identity
            memo[particle] = inner
            inner
          end
          @memo.compare_by_identity
          @state = 0
          entry, exit_state = compile_particles(particles)
          @accepting << exit_state
          @start = entry
        end

        def match(children)
          current = closure([@start])
          children.each_with_index do |child, index|
            current = advance(current, child)
            if current.empty?
              return Result.new(matched: false, fail_index: index,
                                fail_reason: :unexpected_child)
            end
          end
          if current.any? { |state| @accepting.include?(state) }
            Result.new(matched: true)
          else
            Result.new(matched: false, fail_index: children.size,
                       fail_reason: :incomplete)
          end
        end

        private

        def advance(states, child)
          next_states = []
          states.each do |from|
            @transitions[from].each do |kind, particle, to|
              next unless transition_accepts?(kind, particle, child)

              next_states << to
            end
          end
          closure(next_states.uniq)
        end

        def closure(states)
          stack = states.dup
          seen = states.dup
          until stack.empty?
            from = stack.pop
            @epsilons[from].each do |to|
              next if seen.include?(to)

              seen << to
              stack << to
            end
          end
          seen
        end

        def transition_accepts?(kind, particle, child)
          per_particle = @memo[particle]
          cached = per_particle[child]
          return cached unless cached.nil?

          value = case kind
                  when :element
                    @element_match.call(child, particle)
                  when :wildcard
                    @wildcard_match.call(child, particle)
                  end
          per_particle[child] = value
        end

        def next_state
          @state += 1
        end

        def compile_particles(particles)
          entry = next_state
          cursor = entry
          particles.each do |particle|
            p_entry, p_exit = compile_particle(particle)
            @epsilons[cursor] << p_entry
            cursor = p_exit
          end
          [entry, cursor]
        end

        def compile_particle(particle)
          case particle
          when Lutaml::Xsd::Sequence, Lutaml::Xml::Schema::Xsd::Sequence
            compile_bounded_container(particle)
          when Lutaml::Xsd::Choice, Lutaml::Xml::Schema::Xsd::Choice
            with_occurrence(particle) do
              compile_choice_particles(@container_particles.call(particle))
            end
          when Lutaml::Xsd::All, Lutaml::Xml::Schema::Xsd::All
            # The all's own bounds wrap the member bitmask: an optional
            # all accepts the empty sequence even with mandatory
            # members (addB31).
            with_occurrence(particle) { compile_all(particle) }
          when Lutaml::Xml::Schema::Xsd::Group
            compile_group(particle)
          when Lutaml::Xsd::Any
            with_occurrence(particle) { leaf_fragment(:wildcard, particle) }
          else
            with_occurrence(particle) { leaf_fragment(:element, particle) }
          end
        end

        def compile_bounded_container(particle)
          with_occurrence(particle) do
            compile_particles(@container_particles.call(particle))
          end
        end

        # Choice branches run in parallel: one shared entry fans out to
        # every branch, every branch exit fans back in.
        def compile_choice_particles(particles)
          entry = next_state
          exit_state = next_state
          particles.each do |particle|
            p_entry, p_exit = compile_particle(particle)
            @epsilons[entry] << p_entry
            @epsilons[p_exit] << exit_state
          end
          [entry, exit_state]
        end

        def compile_group(particle)
          container = Array(@group_particles.call(particle)).first
          return empty_fragment unless container

          with_occurrence(particle) { compile_container_body(container) }
        end

        # A group ref expands to its declaration's container, whose own
        # kind (sequence vs choice vs all) decides the wiring. Imported
        # documents parse to the lutaml-model container classes —
        # groupO004's xs:all compiled ORDERED before both All classes
        # were wired to the bitmask.
        def compile_container_body(container)
          if container.is_a?(Lutaml::Xsd::Choice) ||
              container.is_a?(Lutaml::Xml::Schema::Xsd::Choice)
            compile_choice_particles(@container_particles.call(container))
          elsif container.is_a?(Lutaml::Xsd::All) ||
              container.is_a?(Lutaml::Xml::Schema::Xsd::All)
            with_occurrence(container) { compile_all(container) }
          else
            compile_particles(@container_particles.call(container))
          end
        end

        # xs:all members: any order, each 0..1 in XSD 1.0. Automaton
        # states are bitmasks of consumed members; a state is accepting
        # when every mandatory member is consumed.
        def compile_all(particle)
          members = @container_particles.call(particle)
          if members.size > MAX_ALL_MEMBERS
            entry, exit_state = compile_choice_particles(members)
            @epsilons[exit_state] << entry
            return [entry, exit_state]
          end
          mandatory = members.each_with_index.sum do |member, index|
            parse_occurs(member.min_occurs, 1).positive? ? (1 << index) : 0
          end
          states = Hash.new { |h, mask| h[mask] = next_state }
          members.each_with_index do |member, index|
            kind = member.is_a?(Lutaml::Xsd::Any) ? :wildcard : :element
            (0...(1 << members.size)).each do |mask|
              next if mask[index] == 1

              @transitions[states[mask]] << [kind, member,
                                             states[mask | (1 << index)]]
            end
          end
          entry = states[0]
          exit_state = next_state
          (0...(1 << members.size)).each do |mask|
            @epsilons[states[mask]] << exit_state if mask.allbits?(mandatory)
          end
          [entry, exit_state]
        end

        def leaf_fragment(kind, particle)
          entry = next_state
          exit_state = next_state
          @transitions[entry] << [kind, particle, exit_state]
          [entry, exit_state]
        end

        def empty_fragment
          state = next_state
          [state, state]
        end

        # Wraps a body fragment with the particle's occurrence range:
        # min mandatory copies, then an unbounded loop on one extra copy
        # or (max - min) optional copies. The first body copy counts
        # toward the bound: with min=0 it IS the first optional copy, so
        # only max-1 more are wired (min=0/max=1 used to compile with
        # capacity 2 — masked for bare elements by the occurrence rule,
        # visible wherever nested group bounds lean on this verdict).
        def with_occurrence(particle)
          min = parse_occurs(particle.min_occurs, 1)
          max = parse_max_occurs(particle.max_occurs, 1)
          return empty_fragment if max.is_a?(Integer) && max.zero?

          entry, exit_state = yield
          cursor = exit_state
          last_entry = entry
          eff_min = [min, MAX_UNROLL].min
          (eff_min - 1).times do
            c_entry, c_exit = yield
            @epsilons[cursor] << c_entry
            cursor = c_exit
            last_entry = c_entry
          end
          final = next_state
          @epsilons[entry] << final if min.zero?
          if max == UNBOUNDED || min > MAX_UNROLL ||
              (max != UNBOUNDED && max - min > MAX_UNROLL)
            @epsilons[cursor] << last_entry
            @epsilons[cursor] << final
            @epsilons[exit_state] << last_entry
            @epsilons[exit_state] << final
          else
            @epsilons[cursor] << final
            optional = max - min - (min.zero? && max.is_a?(Integer) ? 1 : 0)
            optional.times do
              c_entry, c_exit = yield
              @epsilons[cursor] << c_entry
              @epsilons[c_exit] << final
              cursor = c_exit
            end
          end
          [entry, final]
        end

        def parse_occurs(value, default)
          return default if value.nil? || value.to_s.empty?

          value.to_i
        end

        def parse_max_occurs(value, default)
          return default if value.nil? || value.to_s.empty?
          return UNBOUNDED if value.to_s == "unbounded"

          value.to_i
        end
      end
    end
  end
end
