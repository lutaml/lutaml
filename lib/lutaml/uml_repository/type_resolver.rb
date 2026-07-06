# frozen_string_literal: true

module Lutaml
  module UmlRepository
    # TypeResolver resolves a UML type name (e.g. an attribute's type, or a
    # generalization parent) to the classifier it refers to, using the
    # package-aware precedence shared by the repository validator and the
    # association index:
    #
    #   1. already-qualified - the type is itself a known qualified name
    #   2. same-package      - "<package_path>::<type>" is a known qualified name
    #   3. simple-name match - some qualified name ends with "::<type>"
    #                          (first match wins; more than one => ambiguous)
    #
    # It is a pure, stateless module so it can run both at index-build time (over
    # the in-progress maps) and at query time (over a frozen Repository's
    # indexes). It performs no mutation and stores no state.
    module TypeResolver
      module_function

      # Primitive type names that resolve to themselves (no classifier).
      # Single source of truth; consumers (validator, association index,
      # Repository#resolve_type) reach it via TypeResolver.resolve.
      PRIMITIVE_TYPES = %w[
        String Integer Boolean Date DateTime Float Double
        Long Short Byte Char Time Decimal
        UnlimitedNatural Real
      ].freeze

      # The outcome of resolving a type name.
      class Result
        attr_reader :qualified_name, :classifier, :candidates

        def initialize(qualified_name: nil, classifier: nil, primitive: false,
                       ambiguous: false, candidates: [])
          @qualified_name = qualified_name
          @classifier = classifier
          @primitive = primitive
          @ambiguous = ambiguous
          # dup + freeze: the simple-name path passes the index's own array;
          # never expose mutable repository index state to callers.
          @candidates = candidates.dup.freeze
        end

        # Resolved when it maps to a qualified name (a classifier or a
        # primitive). Mirrors the validator's "valid unless nil" contract, so an
        # ambiguous-but-matched type is still resolved (not an error).
        def resolved?
          !@qualified_name.nil?
        end

        def primitive?
          @primitive
        end

        def ambiguous?
          @ambiguous
        end
      end

      UNRESOLVED = Result.new.freeze

      # Resolve a type name to a Result.
      #
      # @param type [String, nil] the type name (e.g. an attribute's type)
      # @param package_path [String, nil] the owning element's package path,
      #   used for the same-package step (skipped when nil/empty)
      # @param qualified_names [Hash{String=>Object}] qname => classifier
      # @param simple_name_to_qnames [Hash{String=>Array<String>}, nil] simple
      #   name => [qname,...]; when nil (e.g. a legacy .lur whose stored indexes
      #   predate this map) the candidate list is rebuilt from qualified_names
      # @param scan_fallback [Boolean] when true, a leaf-name map miss falls
      #   back to scanning qualified names by suffix (which also resolves
      #   partially-qualified references). The association index passes false to
      #   preserve its historical map-only behaviour (it never scanned, so a
      #   partially-qualified generalization parent must not create an edge).
      # @return [Result]
      def resolve(type:, package_path:, qualified_names:,
                  simple_name_to_qnames: nil, scan_fallback: true)
        return UNRESOLVED if type.to_s.empty?

        # Classifier matches take precedence over the primitive list, so a real
        # class named like a primitive (e.g. a domain "Date") still resolves and
        # is reachable by inheritance/navigation. Primitive is the fallback only
        # when no classifier matches.
        direct_result(type, qualified_names) ||
          same_package_result(type, package_path, qualified_names) ||
          simple_name_result(type, qualified_names, simple_name_to_qnames,
                             scan_fallback) ||
          primitive_result(type, qualified_names) ||
          UNRESOLVED
      end

      def primitive_result(type, qualified_names)
        return unless PRIMITIVE_TYPES.include?(type)

        Result.new(qualified_name: type, classifier: qualified_names[type],
                   primitive: true)
      end

      def direct_result(type, qualified_names)
        matched(type, qualified_names, [type]) if qualified_names.key?(type)
      end

      def same_package_result(type, package_path, qualified_names)
        return if package_path.to_s.empty?

        local = "#{package_path}::#{type}"
        matched(local, qualified_names, [local]) if qualified_names.key?(local)
      end

      def simple_name_result(type, qualified_names, simple_name_to_qnames,
                             scan_fallback)
        candidates = candidate_qnames(type, qualified_names,
                                      simple_name_to_qnames, scan_fallback)
        return if candidates.empty?

        matched(candidates.first, qualified_names, candidates,
                ambiguous: candidates.size > 1)
      end

      def matched(qname, qualified_names, candidates, ambiguous: false)
        Result.new(qualified_name: qname, classifier: qualified_names[qname],
                   candidates: candidates, ambiguous: ambiguous)
      end

      # Simple-name candidates in qualified_names insertion order. Prefers the
      # prebuilt index; falls back to scanning qualified_names (legacy packages
      # whose stored indexes predate the simple-name map). The scan matches the
      # validator's historical `end_with?("::<type>")` first-match exactly.
      def candidate_qnames(type, qualified_names, simple_name_to_qnames,
                           scan_fallback)
        mapped = mapped_candidates(type, simple_name_to_qnames)
        return mapped if mapped
        return [] unless scan_fallback
        # When the prebuilt map exists it is authoritative for bare (leaf)
        # names — every classifier's name is a key — so a miss is a definitive
        # miss and resolve falls through to the primitive step in O(1) instead
        # of scanning every qualified name (primitives are the common case).
        return [] if simple_name_to_qnames && !type.include?("::")

        # No map (legacy packages whose stored indexes predate it), or a
        # PARTIALLY-qualified reference like "Pkg::Class" that the leaf-keyed
        # map cannot answer: scan qualified names by suffix, matching the
        # validator's historical end_with? behaviour exactly.
        suffix = "::#{type}"
        qualified_names.keys.select { |qname| qname.end_with?(suffix) }
      end

      # uniq: a stored index may hold the same qname twice when two same-named
      # classifiers in one package collided at build time — one qualified name
      # is one candidate, not a spurious ambiguity. Returns nil on a map miss.
      def mapped_candidates(type, simple_name_to_qnames)
        mapped = simple_name_to_qnames && simple_name_to_qnames[type]
        mapped.uniq if mapped && !mapped.empty?
      end
    end
  end
end
