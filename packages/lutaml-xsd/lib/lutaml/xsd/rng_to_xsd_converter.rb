# frozen_string_literal: true

module Lutaml
  module Xsd
    # Converts an Rng::Grammar object to an Lutaml::Xml::Schema::Xsd::Schema.
    # Follows the same mapping logic as jing-trang's RNG-to-XSD conversion.
    class RngToXsdConverter
      # @param grammar [Rng::Grammar] The parsed RNG grammar
      # @param file_path [String] Original file path (for error messages)
      def initialize(grammar, file_path: nil)
        @grammar = grammar
        @file_path = file_path

        # Build define name -> Rng::Define lookup
        @define_map = build_define_map(grammar)

        # Cache which defines wrap a single element (define_is_element_like?)
        @element_like_define = {}

        # Collision detection: element_name -> [define_names]
        @element_name_collisions = build_element_name_collisions

        # Track converted defines to prevent infinite recursion
        @converting = Set.new

        # Cache: define_name -> { group:, attribute_group:, simple_type:, complex_type:, element: }
        @define_results = {}
      end

      # Convert the grammar to an XSD Schema
      # @return [Lutaml::Xml::Schema::Xsd::Schema]
      def convert
        @schema = Lutaml::Xml::Schema::Xsd::Schema.new
        @schema.element_form_default = "qualified"
        schema = @schema

        # Set target_namespace only if it's a real value (not uninitialized)
        ns = @grammar.ns
        schema.target_namespace = ns unless ns.nil? || ns.is_a?(Lutaml::Model::UninitializedClass)

        # Phase 0: Convert includes from RNC/RNG file
        convert_includes(schema)

        # Phase 1: Convert all defines
        convert_all_defines

        # Phase 2: Convert start elements and top-level elements
        convert_start_elements(schema)
        convert_grammar_elements(schema)

        schema
      end

      # Nested pattern accessors per container class — declared model
      # attributes on rng 0.3.9 (Grammar carries only element; Start/List
      # and Attribute omit one kind each; the other containers declare
      # the full set).
      FULL_PATTERN_KINDS = %w[element ref choice group interleave mixed
                              optional zeroOrMore oneOrMore text empty
                              value data list notAllowed attribute].freeze
      PATTERN_KINDS_BY_CLASS = {
        "Rng::Element" => FULL_PATTERN_KINDS,
        "Rng::Choice" => FULL_PATTERN_KINDS,
        "Rng::Group" => FULL_PATTERN_KINDS,
        "Rng::Interleave" => FULL_PATTERN_KINDS,
        "Rng::Mixed" => FULL_PATTERN_KINDS,
        "Rng::Optional" => FULL_PATTERN_KINDS,
        "Rng::ZeroOrMore" => FULL_PATTERN_KINDS,
        "Rng::OneOrMore" => FULL_PATTERN_KINDS,
        "Rng::Define" => FULL_PATTERN_KINDS,
        "Rng::Attribute" =>
          %w[ref choice group interleave mixed optional zeroOrMore
             oneOrMore text empty value data list notAllowed attribute],
        "Rng::Start" =>
          %w[element ref choice group interleave mixed optional zeroOrMore
             oneOrMore text empty value data list notAllowed],
        "Rng::List" =>
          %w[element ref choice group interleave mixed optional zeroOrMore
             oneOrMore text empty value data notAllowed],
        "Rng::Grammar" => %w[element],
      }.freeze

      private

      # Occurrence attributes exist on particle models (element,
      # containers); attribute declarations and attribute groups carry none.
      def occurrence_assignable?(node)
        !node.is_a?(Lutaml::Xml::Schema::Xsd::Attribute) &&
          !node.is_a?(Lutaml::Xml::Schema::Xsd::AttributeGroup)
      end

      # Resolve a value that might be Lutaml::Model::UninitializedClass to nil or a string
      def resolve_string(value)
        return nil if value.nil? || value.is_a?(Lutaml::Model::UninitializedClass)

        value.to_s
      end

      # Collect all pattern children from an RNG container node
      # Returns an array of non-nil pattern objects
      def get_all_patterns(container)
        kinds = PATTERN_KINDS_BY_CLASS[container.class.name] || []
        kinds.flat_map { |attr| Array(container.public_send(attr)) }
          .compact
          .reject { |child| child.is_a?(Lutaml::Model::UninitializedClass) }
      end

      # Get the single pattern child from a Start
      def get_start_pattern(start)
        kinds = PATTERN_KINDS_BY_CLASS[start.class.name] || []
        kinds.map { |attr| start.public_send(attr) }
          .find do |child|
            child && !child.is_a?(Array) &&
              !child.is_a?(Lutaml::Model::UninitializedClass)
          end
      end

      # Build define name -> Define lookup from grammar (including divs)
      def build_define_map(grammar)
        map = {}
        collect_defines(grammar, map)
        map
      end

      def collect_defines(container, map)
        (container.define || []).each do |d|
          map[d.name] = d if d.name
        end
        (container.div || []).each { |div| collect_defines(div, map) }
      end

      # Phase 0: Convert include directives from the original RNC/RNG file
      def convert_includes(schema)
        return unless @file_path

        includes = extract_includes(@file_path)
        includes.each do |inc_location|
          inc = Lutaml::Xml::Schema::Xsd::Include.new(schema_location: inc_location)
          schema.include(inc)
        end
      end

      # Extract include schemaLocation values from an RNC or RNG file
      def extract_includes(file_path)
        content = File.read(file_path)
        locations = []

        case File.extname(file_path).downcase
        when ".rnc"
          # RNC format: include "path" { ... }
          content.scan(/^include\s+"([^"]+)"/) do
            loc = Regexp.last_match(1)
            # Convert .rnc extension to .xsd
            locations << loc.sub(/\.rnc$/i, ".xsd")
          end
        when ".rng"
          # RNG format: <include href="path"/>
          content.scan(/<include\s+[^>]*href\s*=\s*"([^"]+)"/) do
            loc = Regexp.last_match(1)
            locations << loc.sub(/\.rng$/i, ".xsd")
          end
        end

        locations
      end

      # Phase 1: Convert all named defines
      def convert_all_defines
        @define_map.each_key do |name|
          convert_define(name)
        end
      end

      # Convert a single define by name, caching results
      def convert_define(name) # rubocop:disable Metrics/MethodLength
        return @define_results[name] if @define_results.key?(name)

        # Cycle guard
        if @converting.include?(name)
          return {}
        end

        @converting.add(name)
        define = @define_map[name]
        unless define
          @converting.delete(name)
          return {}
        end

        result = {}
        patterns = get_all_patterns(define)

        # Unwrap single Group child: when the RNC parser wraps all define
        # patterns in a Group, extract the Group's children directly.
        if patterns.length == 1 && patterns.first.is_a?(Rng::Group)
          patterns = get_all_patterns(patterns.first)
        end

        # Classify children into particles, attributes, and data
        particles = []
        attributes = []
        data_patterns = []

        patterns.each do |p|
          case p
          when Rng::Attribute
            attributes << p
          when Rng::Data, Rng::Value, Rng::List, Rng::Text
            data_patterns << p
          when Rng::Ref
            if ref_resolves_to_attribute_group?(p)
              attributes << p
            else
              particles << p
            end
          else
            # Check if this is an attribute-like pattern (e.g. Optional wrapping Attribute)
            if attribute_like_pattern?(p)
              attributes << p
            else
              particles << p
            end
          end
        end

        has_elements = particles.any? { |p| contains_element?(p) }

        if attributes.empty? && !has_elements && data_patterns.any?
          # Pure data define -> SimpleType
          st = build_simple_type_from_patterns(name, data_patterns)
          if st
            @schema&.simple_type(st)
            result[:simple_type] = st
          end
        elsif attributes.any? && !has_elements && particles.empty?
          # Pure attribute define -> AttributeGroup
          ag = build_attribute_group(name, attributes)
          @schema&.attribute_group(ag)
          result[:attribute_group] = ag
        elsif has_elements || particles.any?
          # Check for single-element define promotion
          single_elem = extract_single_element(particles)
          # Always promote the element to top-level
          xsd_elem = convert_element_pattern(single_elem)
          if single_elem && attributes.empty?
            elem_name = element_name(single_elem)
            if should_promote_to_element?(name, elem_name)
              if xsd_elem
                @schema&.element(xsd_elem)

                if xsd_elem&.complex_type
                  ct = xsd_elem.complex_type
                  ct.name = "#{elem_name}_type"
                  @schema&.complex_type(ct)
                  xsd_elem.type = "#{elem_name}_type"
                  xsd_elem.complex_type = nil
                end

                # Always store the element result so refs resolve to element refs
                # rather than group refs (groups are invalid inside xs:all).
                result[:element] = xsd_elem

                if name != elem_name
                  # Define name differs: also create a group referencing the
                  # promoted top-level element.
                  grp = Lutaml::Xml::Schema::Xsd::Group.new(
                    name: name,
                    sequence: Lutaml::Xml::Schema::Xsd::Sequence.new(
                      element: [Lutaml::Xml::Schema::Xsd::Element.new(ref: elem_name)],
                    ),
                  )
                  @schema&.group(grp)
                  result[:group] = grp
                end
              end
            elsif xsd_elem
              grp = Lutaml::Xml::Schema::Xsd::Group.new(
                name: name,
                sequence: Lutaml::Xml::Schema::Xsd::Sequence.new(element: [xsd_elem]),
              )
              @schema&.group(grp)
              result[:group] = grp
            end
          elsif attributes.any?
            # Both particles and attributes -> named ComplexType
            ct = build_complex_type(name, particles, attributes, false)
            @schema&.complex_type(ct)
            result[:complex_type] = ct
          else
            # Pure particle define -> Group
            grp = build_group(name, particles)
            if grp
              @schema&.group(grp)
              result[:group] = grp
            end
          end
        end

        @define_results[name] = result
        @converting.delete(name)
        result
      end

      # Build mapping from element_name to define_names for collision detection.
      # A define that wraps a single Rng::Element may be promotable to a
      # top-level xs:element. When two defines wrap elements with the same name,
      # only one should be promoted.
      def build_element_name_collisions
        map = {}
        @define_map.each_key do |name|
          define = @define_map[name]
          patterns = get_all_patterns(define)
          if patterns.length == 1 && patterns.first.is_a?(Rng::Group)
            patterns = get_all_patterns(patterns.first)
          end

          particles = patterns.reject do |p|
            p.is_a?(Rng::Attribute) ||
              p.is_a?(Rng::Data) || p.is_a?(Rng::Value) ||
              p.is_a?(Rng::List) || p.is_a?(Rng::Text) ||
              (p.is_a?(Rng::Ref) && ref_resolves_to_attribute_group?(p)) ||
              attribute_like_pattern?(p)
          end

          single_elem = extract_single_element(particles)
          next unless single_elem

          elem_name = element_name(single_elem)
          next unless elem_name

          (map[elem_name] ||= []) << name
        end
        map
      end

      # Decide whether a define wrapping a single element should be promoted to
      # a top-level xs:element. Trang always promotes single-element defines
      # (regardless of name matching) UNLESS multiple defines wrap elements with
      # the same name (name collision). In collision case, all colliding defines
      # become xs:group with inline elements.
      #
      # When define_name != elem_name, the define result becomes a xs:group ref
      # while the element is still promoted to top-level.
      def should_promote_to_element?(define_name, elem_name)
        return false unless define_name && elem_name

        # Name collision: multiple defines wrap elements with the same name
        return false if @element_name_collisions[elem_name]&.length.to_i > 1

        true
      end

      # Check if a Ref resolves to an attribute group define
      # Check if a ref name follows attribute group naming conventions.
      # Used as a fallback when the define is not in @define_map (e.g., from
      # unresolved include files where the Rng gem's IncludeProcessor fails).
      def attribute_group_name?(name)
        name.end_with?("Attributes", "Id")
      end

      def ref_resolves_to_attribute_group?(ref)
        return false unless ref.is_a?(Rng::Ref) && ref.name

        define = @define_map[ref.name]
        unless define
          # Ref not in define map — likely from an unresolved include.
          # Fall back to name convention: attribute groups in RELAX NG
          # schemas consistently end with "Attributes" or "Id".
          return attribute_group_name?(ref.name)
        end

        patterns = get_all_patterns(define)
        # Unwrap single Group
        if patterns.length == 1 && patterns.first.is_a?(Rng::Group)
          patterns = get_all_patterns(patterns.first)
        end

        # An attribute group define has only Attribute-like and attribute-group Ref children
        # (no elements, no particle-generating patterns)
        patterns.all? do |p|
          attribute_like_pattern?(p)
        end
      end

      # Check if a pattern is attribute-like: an Attribute, an occurrence wrapper
      # around an attribute, or a Ref that resolves to an attribute group.
      def attribute_like_pattern?(pattern)
        case pattern
        when Rng::Attribute
          true
        when Rng::Optional, Rng::ZeroOrMore, Rng::OneOrMore
          children = get_all_patterns(pattern)
          children.any? { |c| attribute_like_pattern?(c) }
        when Rng::Ref
          ref_resolves_to_attribute_group?(pattern)
        else
          false
        end
      end

      # Check if a Ref resolves to a define that is a pure data define (simple type)
      def ref_resolves_to_simple_type?(ref)
        return false unless ref.is_a?(Rng::Ref) && ref.name

        result = convert_define(ref.name)
        result.key?(:simple_type)
      end

      # Check if a Ref resolves to a define that was promoted to a top-level element
      def ref_resolves_to_element?(ref)
        return false unless ref.is_a?(Rng::Ref) && ref.name

        # Ensure the define is converted
        convert_define(ref.name)
        @define_results[ref.name]&.key?(:element)
      end

      # Check if a list of particles contains exactly one element (possibly wrapped)
      # Returns the bare Rng::Element or nil
      def extract_single_element(particles)
        return nil unless particles.length == 1

        unwrap_to_element(particles.first)
      end

      # Unwrap occurrence wrappers to get the inner element
      def unwrap_to_element(pattern)
        case pattern
        when Rng::Element
          pattern
        when Rng::Optional, Rng::ZeroOrMore, Rng::OneOrMore, Rng::Mixed
          children = get_all_patterns(pattern)
          return nil unless children.length == 1

          unwrap_to_element(children.first)
        end
      end

      # Check if a pattern (possibly nested in wrappers) contains an element
      def contains_element?(pattern)
        case pattern
        when Rng::Element
          true
        when Rng::Choice, Rng::Group, Rng::Interleave, Rng::Mixed,
             Rng::Optional, Rng::ZeroOrMore, Rng::OneOrMore
          get_all_patterns(pattern).any? { |p| contains_element?(p) }
        when Rng::Ref
          define = @define_map[pattern.name]
          unless define
            # Unknown ref (from unresolved include): conservative assumption
            # that it contains elements, since refs in RNC grammars typically
            # point to element patterns and we must preserve Choice structure
            return true
          end

          # Check if this ref resolves to an element define
          convert_define(pattern.name)
          return true if @define_results[pattern.name]&.key?(:element)

          get_all_patterns(define).any? { |p| contains_element?(p) }
        else
          false
        end
      end

      # Check if a pattern contains data/value (no elements, no text mixed in)
      def contains_data?(pattern)
        case pattern
        when Rng::Data, Rng::Value
          true
        when Rng::Choice, Rng::Group, Rng::Interleave
          children = get_all_patterns(pattern)
          children.any? { |p| contains_data?(p) } &&
            children.none? { |p| contains_element?(p) }
        when Rng::Optional, Rng::ZeroOrMore, Rng::OneOrMore
          get_all_patterns(pattern).any? { |p| contains_data?(p) }
        when Rng::Ref
          define = @define_map[pattern.name]
          return false unless define

          get_all_patterns(define).any? { |p| contains_data?(p) }
        else
          false
        end
      end

      # Build a SimpleType from data/value patterns
      def build_simple_type_from_patterns(name, patterns)
        if patterns.size == 1
          build_simple_type(name, patterns.first)
        else
          types = patterns.filter_map { |p| build_simple_type(nil, p) }
          return nil if types.empty?

          if types.size == 1
            types.first.name = name
            types.first
          else
            Lutaml::Xml::Schema::Xsd::SimpleType.new(
              name: name,
              union: Lutaml::Xml::Schema::Xsd::Union.new(
                simple_type: types,
              ),
            )
          end
        end
      end

      # Build a SimpleType from a single data/value/list pattern
      def build_simple_type(name, pattern)
        case pattern
        when Rng::Data
          build_simple_type_from_data(name, pattern)
        when Rng::Value
          build_simple_type_from_value(name, pattern)
        when Rng::List
          build_simple_type_from_list(name, pattern)
        when Rng::Text
          Lutaml::Xml::Schema::Xsd::SimpleType.new(
            name: name,
            restriction: Lutaml::Xml::Schema::Xsd::RestrictionSimpleType.new(
              base: "xs:string",
            ),
          )
        when Rng::Choice
          values = collect_values(pattern)
          if values.any?
            build_enum_simple_type(name, values)
          else
            child_types = get_all_patterns(pattern).filter_map { |p| build_simple_type(nil, p) }
            return nil if child_types.empty?

            Lutaml::Xml::Schema::Xsd::SimpleType.new(
              name: name,
              union: Lutaml::Xml::Schema::Xsd::Union.new(
                simple_type: child_types,
              ),
            )
          end
        when Rng::Ref
          result = convert_define(pattern.name)
          if result[:simple_type]
            Lutaml::Xml::Schema::Xsd::SimpleType.new(
              name: name,
              restriction: Lutaml::Xml::Schema::Xsd::RestrictionSimpleType.new(
                base: pattern.name,
              ),
            )
          end
        end
      end

      # Build SimpleType from Rng::Data
      def build_simple_type_from_data(name, data)
        type_name = data_type_name(data)
        restriction = Lutaml::Xml::Schema::Xsd::RestrictionSimpleType.new(base: type_name)

        (data.param || []).each do |param|
          facet = build_facet(param)
          restriction.send(facet.first, facet.last) if facet
        end

        Lutaml::Xml::Schema::Xsd::SimpleType.new(
          name: name,
          restriction: restriction,
        )
      end

      # Build SimpleType from Rng::Value (single enumeration)
      def build_simple_type_from_value(name, value)
        type_name = value.type ? "xs:#{value.type}" : "xs:string"
        Lutaml::Xml::Schema::Xsd::SimpleType.new(
          name: name,
          restriction: Lutaml::Xml::Schema::Xsd::RestrictionSimpleType.new(
            base: type_name,
            enumeration: [
              Lutaml::Xml::Schema::Xsd::Enumeration.new(value: value.value),
            ],
          ),
        )
      end

      # Build SimpleType from Rng::List
      def build_simple_type_from_list(name, list_pattern)
        inner = get_all_patterns(list_pattern).first
        item_type = inner ? resolve_data_type(inner) : "xs:string"
        Lutaml::Xml::Schema::Xsd::SimpleType.new(
          name: name,
          list: Lutaml::Xml::Schema::Xsd::List.new(item_type: item_type),
        )
      end

      # Build a SimpleType with enumeration facets from a list of values
      def build_enum_simple_type(name, values)
        type_name = values.first[:type] || "xs:string"
        enums = values.map do |v|
          Lutaml::Xml::Schema::Xsd::Enumeration.new(value: v[:value])
        end
        Lutaml::Xml::Schema::Xsd::SimpleType.new(
          name: name,
          restriction: Lutaml::Xml::Schema::Xsd::RestrictionSimpleType.new(
            base: type_name,
            enumeration: enums,
          ),
        )
      end

      # Collect all Value patterns from a choice tree
      def collect_values(pattern)
        case pattern
        when Rng::Value
          [{ type: pattern.type ? "xs:#{pattern.type}" : nil, value: pattern.value }]
        when Rng::Choice
          get_all_patterns(pattern).flat_map { |p| collect_values(p) }
        else
          []
        end
      end

      # Resolve a data/value pattern to an XSD type name string
      def resolve_data_type(pattern)
        case pattern
        when Rng::Data
          data_type_name(pattern)
        when Rng::Value
          pattern.type ? "xs:#{pattern.type}" : "xs:string"
        when Rng::Ref
          pattern.name
        else
          "xs:string"
        end
      end

      # Get the XSD type name for a Data pattern
      def data_type_name(data)
        lib = resolve_string(data.datatypeLibrary) || resolve_string(@grammar.datatypeLibrary) || ""
        type = data.type || "string"

        if lib.empty? || lib.include?("XMLSchema-datatypes") || lib.include?("XMLSchema")
          type = "QName" if type == "NOTATION"
        else
          warn "Warning: Non-XSD datatype library '#{lib}' in #{@file_path}, " \
               "using type name as-is: #{type}"
        end

        "xs:#{type}"
      end

      # Build an XSD facet from an RNG Param
      def build_facet(param)
        case param.name
        when "minInclusive"
          [:min_inclusive, Lutaml::Xml::Schema::Xsd::MinInclusive.new(value: param.value)]
        when "maxInclusive"
          [:max_inclusive, Lutaml::Xml::Schema::Xsd::MaxInclusive.new(value: param.value)]
        when "minExclusive"
          [:min_exclusive, Lutaml::Xml::Schema::Xsd::MinExclusive.new(value: param.value.to_i)]
        when "maxExclusive"
          [:max_exclusive, Lutaml::Xml::Schema::Xsd::MaxExclusive.new(value: param.value.to_i)]
        when "pattern"
          [:pattern, Lutaml::Xml::Schema::Xsd::Pattern.new(value: param.value)]
        when "totalDigits"
          [:total_digits, Lutaml::Xml::Schema::Xsd::TotalDigits.new(value: param.value)]
        when "fractionDigits"
          [:fraction_digits, Lutaml::Xml::Schema::Xsd::FractionDigits.new(value: param.value)]
        when "minLength"
          [:min_length, Lutaml::Xml::Schema::Xsd::MinLength.new(value: param.value.to_i)]
        when "maxLength"
          [:max_length, Lutaml::Xml::Schema::Xsd::MaxLength.new(value: param.value.to_i)]
        when "length"
          [:length, Lutaml::Xml::Schema::Xsd::Length.new(value: param.value.to_i)]
        when "whiteSpace"
          [:white_space, Lutaml::Xml::Schema::Xsd::WhiteSpace.new(value: param.value)]
        else
          warn "Warning: Unknown RNG param '#{param.name}' in #{@file_path}"
          nil
        end
      end

      # Build an AttributeGroup from attribute patterns
      def build_attribute_group(name, attributes)
        xsd_attrs = []
        attr_group_refs = []

        attributes.each do |a|
          case a
          when Rng::Ref
            attr_group_refs << Lutaml::Xml::Schema::Xsd::AttributeGroup.new(ref: a.name)
          when Rng::Optional, Rng::ZeroOrMore, Rng::OneOrMore
            # Unwrap occurrence wrappers to reach the inner attribute pattern
            inner = get_all_patterns(a).find { |p| p.is_a?(Rng::Attribute) }
            if inner
              converted = convert_attribute_pattern(inner)
              xsd_attrs << converted if converted
            end
          else
            converted = convert_attribute_pattern(a)
            xsd_attrs << converted if converted
          end
        end

        ag = Lutaml::Xml::Schema::Xsd::AttributeGroup.new(
          name: name,
          attribute: xsd_attrs,
        )
        ag.attribute_group = attr_group_refs if attr_group_refs.any?
        ag
      end

      # Build a Group (with Sequence) from particle patterns
      def build_group(name, particles)
        # Separate attribute group refs from actual particles
        actual_particles, _attr_group_refs = classify_particles_and_attr_refs(particles)

        children = actual_particles.filter_map { |p| convert_pattern(p, :particle) }
        return nil if children.empty?

        # If there's exactly one child and it's already a sequence/choice, use it directly
        if children.size == 1
          child = children.first
          case child
          when Lutaml::Xml::Schema::Xsd::Sequence
            return Lutaml::Xml::Schema::Xsd::Group.new(
              name: name,
              sequence: child,
            )
          when Lutaml::Xml::Schema::Xsd::Choice
            return Lutaml::Xml::Schema::Xsd::Group.new(
              name: name,
              choice: child,
            )
          end
        end

        # Wrap in a sequence
        seq = wrap_in_sequence(children)
        Lutaml::Xml::Schema::Xsd::Group.new(
          name: name,
          sequence: seq,
        )
      end

      # Build a named ComplexType from particle and attribute patterns
      def build_complex_type(name, particles, attributes, mixed)
        # Separate attribute group refs from actual particles
        actual_particles, particle_attr_refs = classify_particles_and_attr_refs(particles)

        # Convert attribute patterns (Rng::Attribute and Rng::Ref to attr groups)
        xsd_attrs = []
        xsd_attr_group_refs = []

        attributes.each do |a|
          if a.is_a?(Rng::Ref)
            xsd_attr_group_refs << Lutaml::Xml::Schema::Xsd::AttributeGroup.new(ref: a.name)
          elsif a.is_a?(Rng::Optional) || a.is_a?(Rng::ZeroOrMore) || a.is_a?(Rng::OneOrMore)
            # Unwrap occurrence wrappers to reach the inner attribute pattern
            inner = get_all_patterns(a).find { |p| p.is_a?(Rng::Attribute) }
            if inner
              converted = convert_attribute_pattern(inner)
              xsd_attrs << converted if converted
            end
          else
            converted = convert_attribute_pattern(a)
            xsd_attrs << converted if converted
          end
        end

        # Merge attr group refs from particle classification
        xsd_attr_group_refs.concat(particle_attr_refs)

        # Build content model: extract qualifying inline elements to top-level
        particle_children = actual_particles.filter_map do |p|
          extracted = extract_inline_element(p)
          extracted || convert_pattern(p, :particle)
        end

        ct = Lutaml::Xml::Schema::Xsd::ComplexType.new(
          name: name,
          mixed: mixed,
          attribute: xsd_attrs,
        )
        ct.attribute_group = xsd_attr_group_refs if xsd_attr_group_refs.any?

        assign_content_model(ct, particle_children)
        ct
      end

      # Classify a list of patterns into actual particles and attribute group refs
      # Returns [actual_particles, attr_group_ref_objects]
      def classify_particles_and_attr_refs(particles)
        actual_particles = []
        attr_refs = []

        particles.each do |p|
          if p.is_a?(Rng::Ref) && ref_resolves_to_attribute_group?(p)
            attr_refs << Lutaml::Xml::Schema::Xsd::AttributeGroup.new(ref: p.name)
          else
            actual_particles << p
          end
        end

        [actual_particles, attr_refs]
      end

      # Check if a particle is an inline element eligible for extraction to a
      # top-level global element declaration. Returns an XSD element ref if
      # extraction applies, nil otherwise.
      #
      # Eligibility: the particle must be an Rng::Element (possibly wrapped in
      # occurrence wrappers Optional/ZeroOrMore/OneOrMore) whose full content
      # tree consists only of Rng::Ref instances (structural ref pattern).
      # Occurrence wrapper semantics are preserved via minOccurs/maxOccurs on
      # the returned ref element.
      def extract_inline_element(particle)
        min_occurs = nil
        max_occurs = nil

        # Unwrap occurrence wrappers, tracking min/max
        case particle
        when Rng::Optional
          min_occurs = "0"
          max_occurs = "1"
          inner = get_all_patterns(particle).first
        when Rng::ZeroOrMore
          min_occurs = "0"
          max_occurs = "unbounded"
          inner = get_all_patterns(particle).first
        when Rng::OneOrMore
          min_occurs = "1"
          max_occurs = "unbounded"
          inner = get_all_patterns(particle).first
        when Rng::Element
          inner = particle
        else
          return nil
        end

        # Must unwrap to an element
        return nil unless inner.is_a?(Rng::Element)

        elem_name = element_name(inner)
        return nil unless elem_name

        patterns = get_all_patterns(inner)

        # Separate attribute patterns from content patterns
        content_patterns = patterns.reject { |pat| pat.is_a?(Rng::Attribute) }

        # Must have at least one content pattern, all must be structural refs
        return nil unless content_patterns.any?
        return nil unless content_patterns.all? { |pat| structural_ref_pattern?(pat) }

        # Convert the element to a top-level global element declaration
        xsd_elem = convert_element_pattern(inner)
        return nil unless xsd_elem

        @schema&.element(xsd_elem)

        # Return a ref element with preserved occurrence attributes
        ref_elem = Lutaml::Xml::Schema::Xsd::Element.new(ref: elem_name)
        ref_elem.min_occurs = min_occurs if min_occurs
        ref_elem.max_occurs = max_occurs if max_occurs
        ref_elem
      end

      # Recursively check if a pattern tree consists entirely of Rng::Ref
      # instances, possibly nested in structural wrappers.
      #
      # Returns true when every leaf (non-container) pattern in the tree is
      # an Rng::Ref. Container patterns (Choice, Group, Interleave, Mixed,
      # Optional, ZeroOrMore, OneOrMore) are recursively checked. Any other
      # pattern type (Data, Value, Text, Element, Attribute, List, Empty,
      # NotAllowed, etc.) causes an immediate false return.
      def structural_ref_pattern?(pattern)
        case pattern
        when Rng::Ref
          true
        when Rng::Choice, Rng::Group, Rng::Interleave,
             Rng::Optional, Rng::ZeroOrMore, Rng::OneOrMore, Rng::Mixed
          children = get_all_patterns(pattern)
          children.any? && children.all? { |c| structural_ref_pattern?(c) }
        else
          false
        end
      end

      # Assign the appropriate content model (sequence/choice/all) to a ComplexType
      def assign_content_model(ctype, children)
        return if children.empty?

        elements = []
        choices = []
        groups = []
        sequences = []

        children.each do |child|
          case child
          when Lutaml::Xml::Schema::Xsd::Element
            elements << child
          when Lutaml::Xml::Schema::Xsd::Choice
            choices << child
          when Lutaml::Xml::Schema::Xsd::Group
            groups << child
          when Lutaml::Xml::Schema::Xsd::Sequence
            sequences << child
          when Lutaml::Xml::Schema::Xsd::All
            ctype.all = child
            return
          end
        end

        if children.size == 1
          child = children.first
          case child
          when Lutaml::Xml::Schema::Xsd::Sequence
            ctype.sequence = child
            return
          when Lutaml::Xml::Schema::Xsd::Choice
            ctype.choice = child
            return
          end
        end

        ctype.sequence = Lutaml::Xml::Schema::Xsd::Sequence.new(
          element: elements,
          choice: choices,
          group: groups,
          sequence: sequences,
        )
      end

      # Phase 2a: Convert start elements
      def convert_start_elements(schema)
        (@grammar.start || []).each do |start|
          pattern = get_start_pattern(start)
          next unless pattern

          case pattern
          when Rng::Element
            xsd_elem = convert_element_pattern(pattern)
            schema.element(xsd_elem) if xsd_elem
          when Rng::Ref
            result = @define_results[pattern.name]
            if result&.dig(:element)
              # Already promoted to top-level element
            elsif result&.dig(:complex_type)
              xsd_elem = Lutaml::Xml::Schema::Xsd::Element.new(
                name: pattern.name,
                type: pattern.name,
              )
              schema.element(xsd_elem)
            end
          end
        end
      end

      # Phase 2b: Convert top-level elements from grammar
      def convert_grammar_elements(schema)
        (@grammar.element || []).each do |rng_elem|
          xsd_elem = convert_element_pattern(rng_elem)
          schema.element(xsd_elem) if xsd_elem
        end
      end

      # Central pattern dispatch
      # @return [Object, nil] An XSD model object, or nil for empty/notAllowed
      def convert_pattern(pattern, context = :particle)
        case pattern
        when Rng::Element
          convert_element_pattern(pattern)
        when Rng::Attribute
          convert_attribute_pattern(pattern)
        when Rng::Choice
          convert_choice_pattern(pattern, context)
        when Rng::Group
          convert_group_pattern(pattern)
        when Rng::Interleave
          convert_interleave_pattern(pattern)
        when Rng::Optional
          convert_occurrence_pattern(pattern, "0", "1")
        when Rng::ZeroOrMore
          convert_occurrence_pattern(pattern, "0", "unbounded")
        when Rng::OneOrMore
          convert_occurrence_pattern(pattern, "1", "unbounded")
        when Rng::Mixed
          convert_mixed_pattern(pattern)
        when Rng::Ref
          convert_ref_pattern(pattern, context)
        when Rng::Data
          convert_data_pattern(pattern, context)
        when Rng::Value
          convert_value_pattern(pattern, context)
        # when Rng::Text
        #   convert_text_pattern(context)
        when Rng::Empty
          nil
        when Rng::List
          convert_list_pattern(pattern)
        else # rubocop:disable Lint/DuplicateBranch,Style/EmptyElse
          nil
        end
      end

      # Convert an RNG element to an XSD element
      def convert_element_pattern(rng_elem)
        name = element_name(rng_elem)
        return nil unless name

        patterns = get_all_patterns(rng_elem)

        # Classify children
        particle_children = []
        attribute_children = []
        attr_group_refs = []
        has_mixed = false
        data_child = nil

        patterns.each do |p|
          case p
          when Rng::Attribute
            attribute_children << p
          when Rng::Ref
            if ref_resolves_to_simple_type?(p)
              data_child = p
            elsif ref_resolves_to_attribute_group?(p)
              attr_group_refs << Lutaml::Xml::Schema::Xsd::AttributeGroup.new(ref: p.name)
            else
              particle_children << p
            end
          when Rng::Mixed
            has_mixed = true
            particle_children.concat(get_all_patterns(p))
          when Rng::Data, Rng::Value
            data_child = p
          when Rng::Text
            data_child ||= p
          when Rng::Empty
            # no content
          else
            particle_children << p
          end
        end

        if !has_mixed &&
            data_child.nil? &&
            attribute_children.any? &&
            particle_children.any?

          has_mixed = true
        end

        xsd_elem = Lutaml::Xml::Schema::Xsd::Element.new(name: name)

        # Add documentation if present
        if rng_elem.documentation
          xsd_elem.annotation = Lutaml::Xml::Schema::Xsd::Annotation.new(
            documentation: [
              Lutaml::Xml::Schema::Xsd::Documentation.new(
                content: rng_elem.documentation.to_s,
              ),
            ],
          )
        end

        if attribute_children.empty? && attr_group_refs.empty? && particle_children.empty? && data_child
          # Simple content element
          assign_simple_type_to_element(xsd_elem, data_child)
        elsif attribute_children.any? || attr_group_refs.any? || particle_children.any?
          # Complex content element
          xsd_attrs = attribute_children.filter_map { |a| convert_attribute_pattern(a) }
          ct = Lutaml::Xml::Schema::Xsd::ComplexType.new(
            name: nil,
            mixed: has_mixed,
            attribute: xsd_attrs,
          )
          ct.attribute_group = attr_group_refs if attr_group_refs.any?

          # If there's also a data child, use simpleContent
          if data_child && particle_children.empty?
            type_name = resolve_data_type(data_child)
            sc = Lutaml::Xml::Schema::Xsd::SimpleContent.new(
              extension: Lutaml::Xml::Schema::Xsd::ExtensionSimpleContent.new(
                base: type_name,
                attribute: xsd_attrs,
              ),
            )
            ct.simple_content = sc
            ct.attribute = []
          else
            converted = particle_children.filter_map do |p|
              extracted = extract_inline_element(p)
              extracted || convert_pattern(p, :particle)
            end
            assign_content_model(ct, converted)
          end

          # Promote named complex types to schema-level collection only
          @schema&.complex_type(ct) if ct.name
          xsd_elem.complex_type = ct
        elsif data_child.is_a?(Rng::Text)
          xsd_elem.type = "xs:string"
        end

        xsd_elem
      end

      # Assign a simple type to an element (inline or via type reference)
      def assign_simple_type_to_element(xsd_elem, data_child)
        case data_child
        when Rng::Text
          xsd_elem.type = "xs:string"
        when Rng::Data
          xsd_elem.type = data_type_name(data_child)
        when Rng::Value
          xsd_elem.type = data_child.type ? "xs:#{data_child.type}" : "xs:string"
        when Rng::Ref
          xsd_elem.type = data_child.name
        end
      end

      # Convert an RNG attribute to an XSD attribute
      def convert_attribute_pattern(rng_attr)
        name = element_name(rng_attr)
        return nil unless name

        xsd_attr = Lutaml::Xml::Schema::Xsd::Attribute.new(
          name: name,
          use: "optional",
        )

        child = get_attribute_child(rng_attr)
        if child
          case child
          when Rng::Data
            xsd_attr.type = data_type_name(child)
          when Rng::Value
            xsd_attr.type = child.type ? "xs:#{child.type}" : "xs:string"
          when Rng::Text
            xsd_attr.type = "xs:string"
          when Rng::Ref
            xsd_attr.type = child.name
          when Rng::Choice
            values = collect_values(child)
            if values.any?
              st = build_enum_simple_type(nil, values)
              xsd_attr.simple_type = st
            else
              xsd_attr.type = "xs:string"
            end
          end
        else
          xsd_attr.type = "xs:string"
        end

        if rng_attr.documentation
          xsd_attr.annotation = Lutaml::Xml::Schema::Xsd::Annotation.new(
            documentation: [
              Lutaml::Xml::Schema::Xsd::Documentation.new(
                content: rng_attr.documentation.to_s,
              ),
            ],
          )
        end

        xsd_attr
      end

      # Get the single pattern child from an Attribute
      def get_attribute_child(attr)
        kinds = PATTERN_KINDS_BY_CLASS[attr.class.name] || []
        kinds.map { |type_name| attr.public_send(type_name) }
          .find do |child|
            child && !child.is_a?(Array) &&
              !child.is_a?(Lutaml::Model::UninitializedClass)
          end
      end

      # Extract element/attribute name from attr_name or name.value;
      # only Rng::Element and Rng::Attribute carry these accessors.
      def element_name(node)
        return nil unless node.is_a?(Rng::Element) || node.is_a?(Rng::Attribute)

        name = node.attr_name
        if name.nil? || name.empty?
          name_val = node.name
          name = name_val.value if name_val.is_a?(Rng::Name)
        end
        name
      end

      # Convert a choice pattern
      # Per jing-trang: choice only includes element children; if any
      # non-element child exists, the result becomes optional
      def convert_choice_pattern(choice, context)
        children = get_all_patterns(choice)
        return nil if children.empty?

        if context == :data
          values = collect_values(choice)
          if values.any? && values.all? { |v| v[:value] }
            return build_enum_simple_type(nil, values)
          end

          types = children.filter_map { |p| build_simple_type(nil, p) }
          return nil if types.empty?

          if types.size == 1
            types.first
          else
            Lutaml::Xml::Schema::Xsd::SimpleType.new(
              union: Lutaml::Xml::Schema::Xsd::Union.new(simple_type: types),
            )
          end
        else
          # Particle context -> XSD Choice
          # Per jing-trang: only include children that contain ELEMENTs;
          # non-element children make the choice optional
          element_children = []
          has_non_element = false

          children.each do |p|
            if contains_element?(p)
              xsd = convert_pattern(p, :particle)
              element_children << xsd if xsd
            else
              has_non_element = true
            end
          end

          return nil if element_children.empty?

          if element_children.size == 1
            result = element_children.first
          else
            elements = element_children.select { |c| c.is_a?(Lutaml::Xml::Schema::Xsd::Element) }
            sequences = element_children.select { |c| c.is_a?(Lutaml::Xml::Schema::Xsd::Sequence) }
            choices = element_children.select { |c| c.is_a?(Lutaml::Xml::Schema::Xsd::Choice) }
            groups = element_children.select { |c| c.is_a?(Lutaml::Xml::Schema::Xsd::Group) }

            result = Lutaml::Xml::Schema::Xsd::Choice.new(
              element: elements,
              sequence: sequences,
              choice: choices,
              group: groups,
            )
          end

          # Per jing-trang: if any non-element child, wrap in optional
          # (attribute groups carry no occurrence attributes)
          if has_non_element && occurrence_assignable?(result)
            result.min_occurs = "0"
            result.max_occurs = "1"
          end

          result
        end
      end

      # Convert a group pattern -> Sequence or single child
      # Per jing-trang: group creates ParticleSequence, but if there's only
      # one child (and no annotation), the child is returned directly
      def convert_group_pattern(group)
        children = get_all_patterns(group)
        return nil if children.empty?

        xsd_children = children.filter_map { |p| convert_pattern(p, :particle) }
        return nil if xsd_children.empty?

        if xsd_children.size == 1
          xsd_children.first
        else
          wrap_in_sequence(xsd_children)
        end
      end

      # Convert an interleave pattern -> All or single child
      # Per jing-trang: interleave always creates ParticleAll unless there's
      # only one child (in which case it's unwrapped to allow element merging)
      def convert_interleave_pattern(interleave)
        children = get_all_patterns(interleave)
        return nil if children.empty?

        xsd_children = children.filter_map { |p| convert_pattern(p, :particle) }
        return nil if xsd_children.empty?

        if xsd_children.size == 1
          xsd_children.first
        else
          Lutaml::Xml::Schema::Xsd::All.new(element: xsd_children)
        end
      end

      # Convert an occurrence wrapper (optional, zeroOrMore, oneOrMore)
      def convert_occurrence_pattern(wrapper, min, max)
        children = get_all_patterns(wrapper)
        return nil if children.empty?

        xsd_children = children.filter_map { |p| convert_pattern(p, :particle) }
        return nil if xsd_children.empty?

        if xsd_children.size == 1
          child = xsd_children.first
          if occurrence_assignable?(child)
            child.min_occurs = min
            child.max_occurs = max
          end
          child
        else
          seq = wrap_in_sequence(xsd_children)
          seq.min_occurs = min
          seq.max_occurs = max
          seq
        end
      end

      # Convert a mixed pattern
      # Per jing-trang: mixed just delegates to its child
      def convert_mixed_pattern(mixed)
        children = get_all_patterns(mixed)
        return nil if children.empty?

        # Per jing-trang: mixed delegates to its single child
        child = children.first
        return nil unless child

        convert_pattern(child, :particle)
      end

      # Convert a ref pattern
      def convert_ref_pattern(ref, context)
        name = ref.name
        return nil unless name

        # Ensure the define is converted
        result = convert_define(name)

        if context == :data
          if result[:simple_type]
            return Lutaml::Xml::Schema::Xsd::SimpleType.new(
              restriction: Lutaml::Xml::Schema::Xsd::RestrictionSimpleType.new(
                base: name,
              ),
            )
          end
          return nil
        end

        # Particle context
        if result[:element]
          # Reference to a define promoted to top-level element -> element ref
          # Use the element's actual name (not the define name) as the ref target,
          # since they may differ (e.g., define "ext_toc" wraps element "name").
          elem_name = result[:element].name
          Lutaml::Xml::Schema::Xsd::Element.new(ref: elem_name)
        elsif result[:group]
          Lutaml::Xml::Schema::Xsd::Group.new(ref: name)
        elsif result[:attribute_group]
          # Should have been caught by classification, but handle gracefully
          Lutaml::Xml::Schema::Xsd::AttributeGroup.new(ref: name)
        elsif result[:complex_type] # rubocop:disable Lint/DuplicateBranch
          # Reference to a complex type - emit group ref
          Lutaml::Xml::Schema::Xsd::Group.new(ref: name)
        elsif result[:simple_type]
          nil
        else # rubocop:disable Lint/DuplicateBranch
          Lutaml::Xml::Schema::Xsd::Group.new(ref: name)
        end
      end

      # Convert a data pattern in particle context
      def convert_data_pattern(data, context)
        if context == :data
          build_simple_type_from_data(nil, data)
        end
      end

      # Convert a value pattern in particle context
      def convert_value_pattern(value, context)
        if context == :data
          build_simple_type_from_value(nil, value)
        end
      end

      # Convert a text pattern in particle context
      # def convert_text_pattern(context)
      #   nil
      # end

      # Convert a list pattern
      def convert_list_pattern(list_pattern)
        inner = get_all_patterns(list_pattern).first
        item_type = inner ? resolve_data_type(inner) : "xs:string"
        Lutaml::Xml::Schema::Xsd::SimpleType.new(
          list: Lutaml::Xml::Schema::Xsd::List.new(item_type: item_type),
        )
      end

      # Wrap multiple children in a Sequence
      def wrap_in_sequence(children)
        elements = []
        choices = []
        groups = []
        sequences = []

        children.each do |child|
          case child
          when Lutaml::Xml::Schema::Xsd::Element
            elements << child
          when Lutaml::Xml::Schema::Xsd::Choice
            choices << child
          when Lutaml::Xml::Schema::Xsd::Group
            groups << child
          when Lutaml::Xml::Schema::Xsd::Sequence
            sequences << child
          when Lutaml::Xml::Schema::Xsd::All # rubocop:disable Lint/DuplicateBranch
            groups << child
          end
        end

        Lutaml::Xml::Schema::Xsd::Sequence.new(
          element: elements,
          choice: choices,
          group: groups,
          sequence: sequences,
        )
      end
    end
  end
end
