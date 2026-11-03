# frozen_string_literal: true

module Expressir
  module P21
    # Validates a {Population} against a loaded schema
    # (TODO.eengine/06 step 2). Single-schema scope: instance keywords
    # must be declared in the given schema; USE/REFERENCE visibility is
    # a later ladder step.
    #
    # Mapping follows ISO 10303-21 clause 12: derived attributes are
    # not mapped (a supertype attribute redeclared as DERIVED keeps its
    # slot, valued `*`), inverse attributes are not mapped, and the
    # value order is supertype attributes first.
    module Validator
      Note = Struct.new(:id, :severity, :instance, :message, keyword_init: true)

      module_function

      # `short_names` maps exchange-structure short names (ISO 10303-21,
      # clause 12.3) to schema entity names, e.g. {"CPT" => "cartesian_point"}.
      def validate(population, schema, short_names: nil)
        short_names = short_names&.transform_keys(&:downcase)
        typing = Typing.new(schema, short_names: short_names)
        notes = []
        check_file_schema(notes, population, schema)
        check_sections(notes, population, schema)
        population.instances.each do |id, instance|
          if instance.is_a?(ComplexRecord)
            check_complex(notes, schema, population, id, instance,
                          short_names, typing)
          else
            check_simple(notes, schema, population, id, instance,
                         short_names, typing)
          end
        end
        notes
      end

      def errors(notes)
        notes.select { |note| note.severity == :error }
      end

      def warnings(notes)
        notes.select { |note| note.severity == :warning }
      end

      def valid?(notes)
        errors(notes).empty?
      end

      def note!(notes, id, severity, instance, message)
        notes << Note.new(id: id, severity: severity, instance: instance,
                          message: message)
      end

      # Annex E (ISO 10303-21 clause 11.2): each DATA section's schema
      # contexts must intersect the declared schema list.
      def check_sections(notes, population, schema)
        known = ([schema.id] +
          Array(population.header["FILE_SCHEMA"]).flatten)
          .filter_map { |name| name.to_s.downcase unless name.to_s.empty? }
        Array(population.sections).each do |section|
          next if section.contexts.empty?
          next if section.contexts.any? do |context|
            known.include?(context.to_s.downcase)
          end

          note!(notes, :p21_section_context, :warning, nil,
                "DATA section '#{section.name}' context(s) " \
                "#{section.contexts.join(', ')} are not in the schema list")
        end
      end

      def check_file_schema(notes, population, schema)
        declared = Array(population.header["FILE_SCHEMA"]).flatten.first
        return unless declared && schema.id
        return if declared.downcase == schema.id.downcase

        note!(notes, :p21_schema_mismatch, :warning, nil,
              "FILE_SCHEMA '#{declared}' does not match schema '#{schema.id}'")
      end

      def check_simple(notes, schema, population, id, record, short_names,
                       typing)
        entity = find_entity(schema, record.keyword, short_names)
        unless entity
          note!(notes, :p21_unknown_entity, :error, id,
                "#{record.keyword} is not declared in schema '#{schema.id}'")
          return
        end

        check_params(notes, schema, population, id, record.params,
                     mapped_slots(entity), typing)
      end

      def check_complex(notes, schema, population, id, complex, short_names,
                        typing)
        pairs = complex.records.filter_map do |record|
          entity = find_entity(schema, record.keyword, short_names)
          unless entity
            note!(notes, :p21_unknown_entity, :error, id,
                  "#{record.keyword} is not declared in schema '#{schema.id}'")
            next nil
          end

          [record, entity]
        end
        return if pairs.empty?

        check_clique(notes, id, pairs.map { |_, entity| entity })
        typing.issues(complex).each do |message|
          note!(notes, :check_p21_complex_instantiation, :error, id,
                "#{id}: #{message}")
        end
        pairs.each do |record, entity|
          slots = explicit_attributes(entity).map { |attr| [attr, false] }
          check_params(notes, schema, population, id, record.params, slots,
                       typing)
        end
      end

      # A complex instance's records must form a valid supertype graph
      # path: they share at least one common supertype.
      def check_clique(notes, id, entities)
        common = closure_keys(entities.first)
        entities.drop(1).each { |entity| common &= closure_keys(entity) }
        return unless common.empty?

        note!(notes, :p21_complex_clique, :error, id,
              "#{id}: complex records share no common supertype")
      end

      def closure_keys(entity)
        keys = entity.supertype_closure.filter_map { |e| e.id&.downcase }
        keys << entity.id&.downcase
      end

      # Part 21 value order: supertype attributes first; an attribute
      # redeclared as DERIVED in the entity keeps its inherited slot,
      # valued `*` (12.2.6).
      def mapped_slots(entity)
        own_derived_keys = own_derived_attributes(entity)
          .filter_map { |attr| attr.id&.downcase }
        inherited = entity.supertype_closure.flat_map do |supertype|
          explicit_attributes(supertype)
        end
        inherited.map do |attr|
          [attr, own_derived_keys.include?(attr.id&.downcase)]
        end + explicit_attributes(entity).map { |attr| [attr, false] }
      end

      def check_params(notes, schema, population, id, params, slots, typing)
        if params.size != slots.size
          note!(notes, :p21_arity_mismatch, :error, id,
                "#{id}: #{params.size} values for #{slots.size} mapped attributes")
        end

        slots.zip(params).each do |(attr, derived_slot), value|
          next if value.nil? || value == :unset

          if derived_slot
            next if value == :derived

            note!(notes, :p21_derived_slot, :error, id,
                  "#{id}: attribute '#{attr.id}' redeclared DERIVED must be '*'")
            next
          end

          check_value(notes, schema, population, id, attr, value)
          slot_type_issues(schema, population, attr&.type, value, typing)
            .each do |(category, message)|
            note!(notes, FINDING_IDS.fetch(category), :error, id,
                  "#{id}: #{message}")
          end
        end
      end

      def check_value(notes, schema, population, id, attr, value)
        case value
        when String
          return unless value.match?(/\A#\d+\z/)

          return if population.instances.key?(value)
          # An id bound in the REFERENCE section names an external
          # instance (ISO 10303-21 clause 10); resolution is remote.
          return if population.references.key?(value)

          note!(notes, :p21_unknown_reference, :error, id,
                "#{id}: reference #{value} has no instance")
        when :derived
          note!(notes, :p21_derived_value, :error, id,
                "#{id}: '*' outside a derived slot")
        when TypedValue
          return if find_entity(schema, value.keyword) || find_type(schema, value.keyword)

          note!(notes, :p21_unknown_typed_keyword, :error, id,
                "#{id}: typed parameter '#{value.keyword}' does not resolve")
        when Enumeration
          items = enumeration_items(schema, attr)
          return unless items

          names = items.filter_map { |item| item.id&.downcase }
          return if names.include?(value.name.downcase)

          note!(notes, :p21_enum_value, :error, id,
                "#{id}: .#{value.name}. is not in attribute '#{attr.id}' enumeration")
        when Array
          value.each { |item| check_value(notes, schema, population, id, attr, item) }
        end
      end

      def explicit_attributes(entity)
        Array(entity.attributes)
          .select { |attr| attr.instance_of?(Model::Declarations::Attribute) }
      end

      def own_derived_attributes(entity)
        Array(entity.attributes)
          .select { |attr| attr.instance_of?(Model::Declarations::DerivedAttribute) }
      end

      def find_entity(schema, keyword, short_names = nil)
        key = keyword.downcase
        Array(schema.entities).find { |entity| entity.id&.downcase == key } ||
          resolve_short_name(schema, key, short_names)
      end

      def resolve_short_name(schema, key, short_names)
        return nil unless short_names.is_a?(Hash) && short_names[key]

        find_entity(schema, short_names[key], nil)
      end

      def find_type(schema, keyword)
        Array(schema.types).find { |type| type.id&.downcase == keyword.downcase }
      end

      def enumeration_items(schema, attr)
        type = attr&.type
        return Array(type.items) if type.is_a?(Model::DataTypes::Enumeration)

        return nil unless type.is_a?(Model::References::SimpleReference)

        declaration = find_type(schema, type.id.to_s)
        underlying = declaration&.underlying_type
        underlying.is_a?(Model::DataTypes::Enumeration) ? Array(underlying.items) : nil
      end

      # ---- TODO.instance/01: value/type conformance ----
      # ISO 10303-11 ch.8 domains over the clause-12 slots. Every
      # finding carries its clause: simple types 8.1.x, aggregation
      # types 8.2.x, named types 8.4.x, attribute domains 9.2.1,
      # complex instantiation 9.2.5/9.2.5.2, domain rules 9.2.2.2.

      FINDING_IDS = {
        domain: :check_p21_value_domain,
        aggregate: :check_p21_aggregate,
        reference: :check_p21_reference_type,
        select: :check_p21_select_arm,
        complex: :check_p21_complex_instantiation,
      }.freeze
      MAX_TYPE_DEPTH = 16
      PRIMITIVE_DOMAINS = {
        Model::DataTypes::Integer => ["INTEGER", "an unquoted integer (8.1.3)"],
        Model::DataTypes::Real => ["REAL", "a number (8.1.2)"],
        Model::DataTypes::Number => ["NUMBER", "a number (8.1.1)"],
        Model::DataTypes::String => ["STRING", "a single-quoted string (8.1.6)"],
        Model::DataTypes::Binary => ["BINARY", "a binary literal (8.1.7)"],
        Model::DataTypes::Boolean => ["BOOLEAN", ".T. or .F. (8.1.5)"],
        Model::DataTypes::Logical => ["LOGICAL", ".T., .F. or .U. (8.1.4)"],
      }.freeze
      private_constant :FINDING_IDS, :MAX_TYPE_DEPTH, :PRIMITIVE_DOMAINS

      def slot_type_issues(schema, population, type, value, typing, depth = 0,
                           seen = {}.compare_by_identity)
        return [] unless type.is_a?(Model::ModelElement)
        return [] if depth >= MAX_TYPE_DEPTH
        if value.is_a?(TypedValue)
          return typed_value_issues(schema, population, type, value, typing,
                                    depth, seen)
        end

        case type
        when Model::Declarations::Type
          defined_type_issues(schema, population, type, value, typing,
                              depth, seen)
        when Model::Declarations::Entity
          reference_issues(schema, population, value, type, typing)
        when Model::References::SimpleReference
          reference_slot_issues(schema, population, type, value, typing,
                                depth, seen)
        when Model::DataTypes::List, Model::DataTypes::Array,
             Model::DataTypes::Set, Model::DataTypes::Bag
          aggregate_issues(schema, population, type, value, typing, depth, seen)
        when Model::DataTypes::Select
          select_issues(schema, population, type, value, typing, depth, seen)
        when Model::DataTypes::Enumeration
          [] # 8.4.1 membership is checked by check_value
        else
          primitive_issues(type, value)
        end
      end

      def reference_slot_issues(schema, population, type, value, typing,
                                depth, seen)
        declaration = find_type(schema, type.id.to_s)
        if declaration.is_a?(Model::Declarations::Type)
          return defined_type_issues(schema, population, declaration, value,
                                     typing, depth, seen)
        end

        entity = find_entity(schema, type.id.to_s)
        return [] unless entity

        reference_issues(schema, population, value, entity, typing)
      end

      def defined_type_issues(schema, population, declaration, value, typing,
                              depth, seen)
        return [] if seen.include?(declaration)

        seen[declaration] = true
        domain_rule_issues(schema, value, declaration) +
          slot_type_issues(schema, population, declaration.underlying_type,
                           value, typing, depth + 1, seen)
      end

      def domain_rule_issues(schema, value, declaration)
        self_value = domain_value(value, declaration)
        return [] if self_value.nil?

        Array(declaration.where_rules).filter_map do |rule|
          next unless rule.expression

          env = Eval::Environment.new(schema: schema).define("self", self_value)
          result = Eval::Expression.evaluate(rule.expression, env)
          next unless logical_false?(result)

          [:domain,
           "value violates domain rule '#{rule.id}' of " \
           "TYPE '#{declaration.id}' (9.2.2.2)"]
        rescue StandardError
          next # an unevaluable domain rule is not a finding here
        end
      end

      def domain_value(value, declaration)
        case value
        when Integer, Float then value
        when String then reference?(value) ? nil : value
        when Enumeration
          Eval::Values::Enumeration.new(type: declaration.id, item: value.name)
        when Binary then Eval::Values::Binary.new(bits: value.hex)
        end
      end

      def logical_false?(result)
        return true if [false, Eval::Values::LOGICAL_FALSE].include?(result)
        return result.value == Eval::Values::LOGICAL_FALSE if result.is_a?(Eval::Values::Logical)

        false
      end

      def primitive_issues(type, value)
        domain, expectation = PRIMITIVE_DOMAINS[type.class]
        return [] unless domain

        ok = case type
             when Model::DataTypes::Integer then value.is_a?(Integer)
             when Model::DataTypes::Real, Model::DataTypes::Number
               value.is_a?(Numeric)
             when Model::DataTypes::String
               value.is_a?(String) && !reference?(value)
             when Model::DataTypes::Binary then value.is_a?(Binary)
             when Model::DataTypes::Boolean, Model::DataTypes::Logical
               logical_literal?(value)
             end
        return [] if ok

        [[:domain, "#{domain} slot requires #{expectation}"]]
      end

      def logical_literal?(value)
        return true if [true, false].include?(value)

        value.is_a?(Enumeration) && %w[T F U].include?(value.name.to_s.upcase)
      end

      def reference_issues(_schema, population, value, entity, typing)
        return [] unless reference?(value)

        target = population.instances[value]
        return [] unless target

        conformed = typing.of(target)
        return [] if conformed.any? do |candidate|
          candidate.id&.safe_downcase == entity.id&.safe_downcase
        end

        [[:reference,
          "reference #{value} conforms to " \
          "#{conformed.filter_map(&:id).join(', ')} but '#{entity.id}' is " \
          "required (9.2.1)"]]
      end

      def typed_value_issues(schema, population, _type, value, typing, depth,
                             seen)
        entity = find_entity(schema, value.keyword)
        if entity
          return reference_issues(schema, population, value.value, entity,
                                  typing)
        end

        declaration = find_type(schema, value.keyword)
        return [] unless declaration.is_a?(Model::Declarations::Type)

        underlying = declaration.underlying_type
        inner = value.value
        if inner.is_a?(Array) && inner.size == 1 && !aggregate?(underlying)
          inner = inner.first
        end
        slot_type_issues(schema, population, underlying, inner, typing,
                         depth + 1, seen)
      end

      def aggregate?(type)
        type.is_a?(Model::DataTypes::List) || type.is_a?(Model::DataTypes::Array) ||
          type.is_a?(Model::DataTypes::Set) || type.is_a?(Model::DataTypes::Bag)
      end

      def aggregate_issues(schema, population, type, value, typing, depth,
                           seen)
        unless value.is_a?(Array)
          return [[:domain, "#{aggregate_name(type)} attribute requires an " + "aggregate value (#{aggregate_section(type)})"]]
        end

        aggregate_bound_issues(type, value) +
          aggregate_unique_issues(type, value) +
          aggregate_element_issues(schema, population, type, value, typing,
                                   depth, seen)
      end

      def aggregate_bound_issues(type, value)
        lower, upper = aggregate_bounds(type)
        issues = []
        if lower && value.size < lower
          issues << [:aggregate, "#{aggregate_name(type)} has #{value.size} " + "element(s), below the bound #{lower} " + "(#{aggregate_section(type)})"]
        end
        if upper && value.size > upper
          issues << [:aggregate, "#{aggregate_name(type)} has #{value.size} " + "element(s), above the bound #{upper} " + "(#{aggregate_section(type)})"]
        end
        issues
      end

      def aggregate_bounds(type)
        [bound_value(type.bound1), bound_value(type.bound2)]
      end

      def bound_value(bound)
        return nil unless bound.is_a?(Model::Literals::Integer)

        bound.value.to_i
      end

      def aggregate_unique_issues(type, value)
        return [] unless type.is_a?(Model::DataTypes::Set)

        keys = value.map { |element| p21_value_key(element) }
        return [] if keys.uniq.size == keys.size

        [[:aggregate, "SET has duplicate elements (8.2.4)"]]
      end

      def aggregate_element_issues(schema, population, type, value, typing,
                                   depth, _seen)
        issues = []
        value.each_with_index do |element, index|
          unset = element.nil? || element == :unset
          if unset
            next unless type.is_a?(Model::DataTypes::Array) && !type.optional

            issues << [:aggregate, "ARRAY element #{index} is unset but the array is not OPTIONAL (8.2.1)"]
            next
          end

          # Sibling elements re-walk the same types with different
          # values: only the walk along one nesting path shares `seen`.
          slot_type_issues(schema, population, type.base_type, element,
                           typing, depth + 1, {}.compare_by_identity)
            .each do |(category, message)|
            issues << [category, "element #{index}: #{message}"]
          end
        end
        issues
      end

      def select_issues(schema, population, type, value, typing, depth, seen)
        arms = select_arms(schema, type, seen)
        return [] if arms.empty?

        select_arm_issues(schema, population, value, arms, typing, depth, seen)
      end

      # Leaf domains of a SELECT: item entities, item defined types, and
      # nested selects, plus the BASED_ON chain (8.4.2).
      def select_arms(schema, type, seen)
        return [] if seen.include?(type)

        seen[type] = true
        arms = []
        Array(type.items).each do |item|
          next unless item.respond_to?(:id) && item.id

          declaration = find_type(schema, item.id.to_s)
          if declaration.is_a?(Model::Declarations::Type)
            underlying = declaration.underlying_type
            if underlying.is_a?(Model::DataTypes::Select)
              arms.concat(select_arms(schema, underlying, seen))
            else
              arms << [:type, declaration]
            end
            next
          end

          entity = find_entity(schema, item.id.to_s)
          arms << [:entity, entity] if entity
        end
        base = based_on_select(schema, type)
        arms.concat(select_arms(schema, base, seen)) if base
        arms
      end

      def based_on_select(schema, type)
        based = type.based_on
        return nil unless based.respond_to?(:id) && based.id

        declaration = find_type(schema, based.id.to_s)
        return nil unless declaration.is_a?(Model::Declarations::Type)

        underlying = declaration.underlying_type
        underlying.is_a?(Model::DataTypes::Select) ? underlying : nil
      end

      def select_arm_issues(schema, population, value, arms, typing, depth,
                            seen)
        if reference?(value)
          target = population.instances[value]
          return [] unless target

          conformed = typing.of(target)
          ok = arms.any? do |(kind, node)|
            kind == :entity &&
              conformed.any? do |candidate|
                candidate.id&.safe_downcase == node.id&.safe_downcase
              end
          end
          return [] if ok

          return [[:select, "reference #{value} fits no arm of the SELECT (8.4.2)"]]
        end

        if value.is_a?(TypedValue)
          ok = arms.any? do |(_kind, node)|
            node.id&.safe_downcase == value.keyword&.downcase
          end
          return [] if ok

          return [[:select, "typed value '#{value.keyword}' fits no arm of the SELECT (8.4.2)"]]
        end

        return [] if value.is_a?(Enumeration) # 8.4.1 membership via check_value

        literal_ok = arms.any? do |(kind, node)|
          kind == :type && slot_type_issues(
            schema, population, node.underlying_type, value, typing,
            depth + 1, seen
          ).empty?
        end
        return [] if literal_ok

        [[:select, "value #{p21_display(value)} fits no arm of the SELECT (8.4.2)"]]
      end

      def reference?(value)
        value.is_a?(String) && value.match?(/\A#\d+\z/)
      end

      def p21_value_key(value)
        case value
        when Enumeration then [:enum, value.name&.downcase]
        when Binary then [:binary, value.hex]
        when Array then [:list, *value.map { |element| p21_value_key(element) }]
        else [:value, value]
        end
      end

      def p21_display(value)
        case value
        when Enumeration then ".#{value.name}."
        when Binary then "%#{value.hex}"
        else value.to_s
        end
      end

      def aggregate_name(type)
        case type
        when Model::DataTypes::List then "LIST"
        when Model::DataTypes::Array then "ARRAY"
        when Model::DataTypes::Set then "SET"
        else "BAG"
        end
      end

      def aggregate_section(type)
        case type
        when Model::DataTypes::List then "8.2.2"
        when Model::DataTypes::Array then "8.2.1"
        when Model::DataTypes::Set then "8.2.4"
        else "8.2.3"
        end
      end
    end
  end
end
