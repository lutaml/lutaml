# frozen_string_literal: true

module Expressir
  module Eval
    # Pure expression evaluation (TODO.sota/02 step 1): ISO 10303-11
    # ch.12 over the value model. Instance-aware operations (attribute
    # access on entities, TYPEOF/USEDIN/EXISTS) arrive with step 3 and
    # raise Error here.
    module Expression
      V = Expressir::Eval::Values

      module_function

      def evaluate(node, env)
        case node
        when Model::Literals::Integer then node.value.to_i
        when Model::Literals::Real then node.value.to_f
        when Model::Literals::String then node.value.to_s
        when Model::Literals::Binary then V::Binary.new(bits: node.value.to_s)
        when Model::Literals::Logical then logical_literal(node)
        when Model::Expressions::BinaryExpression then evaluate_binary(node, env)
        when Model::Expressions::UnaryExpression then evaluate_unary(node, env)
        when Model::Expressions::Interval then evaluate_interval(node, env)
        when Model::Expressions::AggregateInitializer
          evaluate_aggregate_initializer(node, env)
        when Model::Expressions::QueryExpression then evaluate_query(node, env)
        when Model::Expressions::FunctionCall then evaluate_call(node, env)
        when Model::References::SimpleReference then evaluate_reference(node, env)
        when Model::References::AttributeReference
          evaluate_attribute_reference(node, env)
        when Model::References::IndexReference then evaluate_index(node, env)
        when Model::References::GroupReference then evaluate_group_reference(node, env)
        else
          raise Error, "unsupported expression #{node.class.name}"
        end
      end

      def logical_literal(node)
        node.value == "TRUE" ? V::Logical.true_value : V::Logical.false_value
      end

      def evaluate_reference(node, env)
        value = env.lookup(node.id)
        return value unless value.nil?

        raise Error, "unbound identifier '#{node.id}'"
      end

      def evaluate_group_reference(node, env)
        base = node.ref
        if base.is_a?(Model::References::SimpleReference) &&
            base.id&.safe_downcase == "self"
          value = env.lookup("self")
          return value if value

          raise Error, "SELF requires an instance context (step 4)"
        end

        raise Error, "instance access requires a population"
      end

      # `color.red` (enumeration members) or `instance.attr`.
      def evaluate_attribute_reference(node, env)
        base = node.ref
        if base.is_a?(Model::References::SimpleReference)
          declaration = find_declared_type(env, base.id)
          if declaration
            return V::Enumeration.new(type: declaration.id,
                                      item: node.attribute.id)
          end
        end

        owner = evaluate(base, env)
        if owner.is_a?(V::Instance)
          return instance_attribute(owner, node.attribute&.id, env)
        end

        raise Error, "instance attribute access requires a population"
      end

      def instance_attribute(instance, attribute_name, env)
        record = instance.record
        record = simple_record_of(record, attribute_name, env) if
          record.is_a?(Expressir::P21::ComplexRecord)
        unless record
          raise Error, "attribute '#{attribute_name}' is not mapped on " \
                       "#{record.keyword}"
        end

        entity = env.entity_for_keyword(record.keyword)
        raise Error, "unknown entity '#{record.keyword}'" unless entity

        index = env.slots_for(entity)[attribute_name.safe_downcase]
        unless index
          raise Error, "attribute '#{attribute_name}' is not mapped on " \
                       "'#{record.keyword}'"
        end

        instance_value(record.params[index], env)
      end

      # P21 record parameters are plain Ruby data; convert them to the
      # evaluator's value model at the instance boundary.
      def instance_value(raw, env)
        case raw
        when :unset, :derived then V::INDETERMINATE
        when Array
          V::Aggregate.of(:list, raw.map { |item| instance_value(item, env) })
        when String
          if raw.start_with?("#")
            env.instance_for(raw) || raw
          else
            raw
          end
        when Expressir::P21::Enumeration
          V::Enumeration.new(type: nil, item: raw.name)
        when Expressir::P21::Binary
          V::Binary.new(bits: raw.hex)
        when Expressir::P21::TypedValue
          instance_value(raw.value, env)
        else raw
        end
      end

      def simple_record_of(complex_record, attribute_name, env)
        Array(complex_record.records).find do |record|
          entity = env.entity_for_keyword(record.keyword)
          entity &&
            env.slots_for(entity).key?(attribute_name.safe_downcase)
        end
      end

      def find_declared_type(env, name)
        schema = env.schema
        return nil unless schema

        Array(schema.types).find do |type|
          type.id&.safe_downcase == name.safe_downcase &&
            type.underlying_type.is_a?(Model::DataTypes::Enumeration)
        end
      end

      def evaluate_aggregate_initializer(node, env)
        V::Aggregate.of(:list, Array(node.items).map do |item|
          evaluate(item.respond_to?(:expression) ? item.expression : item, env)
        end)
      end

      def evaluate_index(node, env)
        base = evaluate(node.ref, env)
        index1 = evaluate(node.index1, env)
        index2 = node.index2 ? evaluate(node.index2, env) : nil
        case base
        when String then string_slice(base, index1, index2)
        when V::Binary then V::Binary.new(bits: string_slice(base.bits, index1, index2))
        when V::Aggregate
          raise Error, "aggregate indexing selects one element (12.6.1)" if index2

          base.elements.fetch(index1 - 1)
        else
          raise Error, "cannot index #{describe(base)}"
        end
      end

      def string_slice(value, index1, index2)
        return value[index1 - 1] unless index2

        value[index1 - 1, index2 - index1 + 1] || ""
      end

      def evaluate_query(node, env)
        source = evaluate(node.aggregate_source, env)
        unless source.is_a?(V::Aggregate)
          raise Error, "QUERY source shall be an aggregate (12.6.7)"
        end

        kept = source.elements.select do |element|
          inner = env.push({ node.id.safe_downcase => element })
          logical?(evaluate(node.expression, inner))
        end
        V::Aggregate.of(source.kind, kept)
      end

      def evaluate_call(node, env)
        callee = node.function
        name = callee.is_a?(Model::References::SimpleReference) ? callee.id : nil
        raise Error, "unsupported call target #{callee.class.name}" unless name

        arguments = Array(node.parameters).map { |arg| evaluate(arg, env) }
        env.interpreter.call(name, arguments)
      end

      def evaluate_unary(node, env)
        operand = evaluate(node.operand, env)
        return V::INDETERMINATE if indeterminate?(operand)

        case node.operator
        when "PLUS" then to_number!(operand)
        when "MINUS" then -to_number!(operand)
        when "NOT"
          logical = as_logical(operand)
          case logical.value
          when V::LOGICAL_TRUE then V::Logical.false_value
          when V::LOGICAL_FALSE then V::Logical.true_value
          else V::Logical.unknown
          end
        end
      end

      def evaluate_interval(node, env)
        left = relational(evaluate(node.low, env), node.operator1,
                          evaluate(node.item, env))
        right = relational(evaluate(node.item, env), node.operator2,
                           evaluate(node.high, env))
        evaluate_logical("AND", left, right)
      end

      LOGICAL_OPS = %w[AND OR XOR].freeze

      def evaluate_binary(node, env)
        operator = node.operator
        left = evaluate(node.operand1, env)
        right = evaluate(node.operand2, env)
        if LOGICAL_OPS.include?(operator)
          return evaluate_logical(operator, left, right)
        end

        return V::Logical.unknown if indeterminate?(left, right)

        case operator
        when "ADDITION" then evaluate_addition(left, right)
        when "SUBTRACTION" then evaluate_difference(left, right)
        when "MULTIPLICATION" then evaluate_intersection(left, right)
        when "REAL_DIVISION" then to_number!(left).to_f / to_number!(right)
        when "INTEGER_DIVISION", "MODULO" then evaluate_div_mod(operator, left, right)
        when "EXPONENTIATION" then to_number!(left)**to_number!(right)
        when "COMBINE"
          raise Error, "complex entity construction requires instances (step 3)"
        else
          evaluate_relational(operator, left, right)
        end
      end

      def evaluate_div_mod(operator, left, right)
        first = truncate(left)
        second = truncate(right)
        operator == "INTEGER_DIVISION" ? first / second : first % second
      end

      # ---- arithmetic (12.1) ----

      def numeric_pair?(left, right)
        left.is_a?(Numeric) && right.is_a?(Numeric)
      end

      def string_pair?(left, right)
        left.is_a?(String) && right.is_a?(String)
      end

      def binary_pair?(left, right)
        left.is_a?(V::Binary) && right.is_a?(V::Binary)
      end

      def aggregate_pair?(left, right)
        left.is_a?(V::Aggregate) && right.is_a?(V::Aggregate)
      end

      def arithmetic(left, right, operator)
        result = to_number!(left).send(operator, to_number!(right))
        both_integer?(left, right) ? result : result.to_f
      end

      def truncate(value)
        value.is_a?(Integer) ? value : to_number!(value).to_f.truncate
      end

      def to_number!(value)
        return value if value.is_a?(Numeric)

        raise Error, "expected a numeric operand, got #{describe(value)}"
      end

      def integer?(value)
        value.is_a?(Integer)
      end

      def both_integer?(left, right)
        integer?(left) && integer?(right)
      end

      def evaluate_addition(left, right)
        return arithmetic(left, right, :+) if numeric_pair?(left, right)
        return left + right if string_pair?(left, right)
        return V::Binary.new(bits: left.bits + right.bits) if binary_pair?(left, right)
        return union(left, right) if left.is_a?(V::Aggregate) || right.is_a?(V::Aggregate)

        raise Error,
              "addition requires numeric, string, binary or aggregate " \
              "operands (12.1, 12.3.2, 12.5.2, 12.6)"
      end

      def evaluate_difference(left, right)
        return arithmetic(left, right, :-) if numeric_pair?(left, right)
        if left.is_a?(V::Aggregate) || right.is_a?(V::Aggregate)
          return aggregate_difference(left, right)
        end

        raise Error,
              "difference requires numeric or aggregate operands (12.1, 12.6)"
      end

      def evaluate_intersection(left, right)
        return arithmetic(left, right, :*) if numeric_pair?(left, right)
        return aggregate_intersection(left, right) if aggregate_pair?(left, right)

        raise Error,
              "intersection requires numeric or aggregate operands (12.1, 12.6)"
      end

      # ---- logical operators (12.4) ----

      def evaluate_logical(operator, left, right)
        left = as_logical(left)
        right = as_logical(right)
        return V::Logical.unknown if [left, right].any? { |l| l.value == :unknown }

        case operator
        when "AND"
          left.value == V::LOGICAL_TRUE && right.value == V::LOGICAL_TRUE ? V::Logical.true_value : V::Logical.false_value
        when "OR"
          left.value == V::LOGICAL_TRUE || right.value == V::LOGICAL_TRUE ? V::Logical.true_value : V::Logical.false_value
        else # XOR
          left.value == right.value ? V::Logical.false_value : V::Logical.true_value
        end
      end

      def as_logical(value)
        return value if value.is_a?(V::Logical)

        raise Error, "logical operator requires logical operands (12.4)"
      end

      def logical?(value)
        value.is_a?(V::Logical) && value.value == V::LOGICAL_TRUE
      end

      # ---- relational (12.2) ----

      def evaluate_relational(operator, left, right)
        case operator
        when "IN" then evaluate_in(left, right)
        when "LIKE" then evaluate_like(left, right)
        when "INSTANCE_EQUAL", "INSTANCE_NOT_EQUAL"
          raise Error, "instance comparison requires instances (step 3)"
        else
          result = relational(left, relational_operator(operator), right)
          operator == "NOT_EQUAL" ? negate(result) : result
        end
      end

      def evaluate_like(left, right)
        hit = like_match?(left, right)
        V::Logical.new(value: hit ? V::LOGICAL_TRUE : V::LOGICAL_FALSE)
      end

      def evaluate_in(element, aggregate)
        return V::Logical.unknown if indeterminate?(element, aggregate)
        unless aggregate.is_a?(V::Aggregate)
          raise Error, "membership requires an aggregate right operand (12.2.3)"
        end

        return V::Logical.true_value if aggregate.elements.any? { |e| values_equal?(element, e) }

        hole = aggregate.elements.any? { |e| indeterminate?(e) }
        V::Logical.new(value: hole ? V::LOGICAL_UNKNOWN : V::LOGICAL_FALSE)
      end

      def relational_operator(operator)
        { "EQUAL" => :"=", "NOT_EQUAL" => :"=", "LESS_THAN" => :<,
          "LESS_THAN_OR_EQUAL" => :"<=", "GREATER_THAN" => :>,
          "GREATER_THAN_OR_EQUAL" => :">=" }.fetch(operator)
      end

      def relational(left, operator, right)
        return V::Logical.unknown if indeterminate?(left, right)

        ordering = order(left, right)
        result = case operator
                 when :"=" then ordering.zero?
                 when :< then ordering.negative?
                 when :"<=" then ordering <= 0
                 when :> then ordering.positive?
                 when :">=" then ordering >= 0
                 end
        V::Logical.new(value: result ? V::LOGICAL_TRUE : V::LOGICAL_FALSE)
      end

      def negate(logical)
        case logical.value
        when V::LOGICAL_TRUE then V::Logical.false_value
        when V::LOGICAL_FALSE then V::Logical.true_value
        else V::Logical.unknown
        end
      end

      # 12.2.1 orderings: numeric, string (code point), binary (bit),
      # logical (false < unknown < true), enumeration (item name;
      # declaration position is the caller's refinement).
      def order(left, right)
        return left <=> right if left.is_a?(Numeric) && right.is_a?(Numeric)
        return left <=> right if left.is_a?(String) && right.is_a?(String)
        return left.bits <=> right.bits if left.is_a?(V::Binary) && right.is_a?(V::Binary)
        return logical_order(left) <=> logical_order(right) if
          left.is_a?(V::Logical) && right.is_a?(V::Logical)
        return left.item <=> right.item if
          left.is_a?(V::Enumeration) && right.is_a?(V::Enumeration)

        raise Error, "cannot compare #{describe(left)} with #{describe(right)}"
      end

      LOGICAL_ORDER = {
        V::LOGICAL_FALSE => 0,
        V::LOGICAL_UNKNOWN => 1,
        V::LOGICAL_TRUE => 2,
      }.freeze

      def logical_order(logical)
        LOGICAL_ORDER.fetch(logical.value)
      end

      # ---- LIKE (12.2.5, table 11) ----

      def like_match?(target, pattern)
        unless target.is_a?(String) && pattern.is_a?(String)
          raise Error, "like requires string operands (12.2.5)"
        end

        match_sequence?(target, pattern.chars, 0)
      end

      def match_sequence?(target, pattern, offset)
        return offset == target.length if pattern.empty?

        char = pattern[0]
        rest = pattern[1..]
        case char
        when "\\" then match_escaped?(target, rest, offset)
        when "*" then match_star?(target, rest, offset)
        when "&" then match_sequence?(target, rest, target.length)
        when "$" then match_dollar?(target, rest, offset)
        when "!" then match_negation?(target, rest, offset)
        else
          match_single?(target, rest, offset) { |tc| char_matches?(char, tc) }
        end
      end

      def match_escaped?(target, rest, offset)
        char = rest[0]
        return false if char.nil?

        match_single?(target, rest[1..], offset) { |tc| tc == char }
      end

      def match_star?(target, rest, offset)
        (offset..target.length).any? do |split|
          match_sequence?(target, rest, split)
        end
      end

      def match_dollar?(target, rest, offset)
        index = target.index(" ", offset) || target.length
        prefix = target[offset...index] || ""
        remaining = target[index..] || ""
        match_sequence?(prefix, rest, 0) && match_sequence?(remaining, [], 0)
      end

      def match_negation?(target, rest, offset)
        negated = rest[0]
        return false if negated.nil? || offset >= target.length

        target_char = target[offset]
        matches = case negated
                  when "@" then target_char.match?(/[[:alpha:]]/)
                  when "^" then target_char.match?(/[[:upper:]]/)
                  when "#" then target_char.match?(/[[:digit:]]/)
                  when "?" then true
                  else target_char == negated
                  end
        return false if matches

        match_sequence?(target, rest[1..], offset + 1)
      end

      def match_single?(target, rest, offset)
        return false if offset >= target.length

        yield(target[offset]) && match_sequence?(target, rest, offset + 1)
      end

      def char_matches?(pattern_char, target_char)
        case pattern_char
        when "@" then target_char.match?(/[[:alpha:]]/)
        when "^" then target_char.match?(/[[:upper:]]/)
        when "#" then target_char.match?(/[[:digit:]]/)
        when "?" then true
        else pattern_char == target_char
        end
      end

      # ---- aggregates (12.6, tables 16-18) ----

      # Table 17: union results take the promoted kind (bag absorbs
      # everything; set over set/element; list over list/element).
      def union(left, right)
        left_agg = left.is_a?(V::Aggregate) ? left : nil
        right_agg = right.is_a?(V::Aggregate) ? right : nil
        kind = union_kind(left_agg&.kind, right_agg&.kind)
        elements = (left_agg&.elements || [left]) +
          (right_agg&.elements || [right])
        V::Aggregate.of(kind, dedup_if_set(kind, elements))
      end

      def union_kind(left_kind, right_kind)
        return :bag if [left_kind, right_kind].include?(:bag)
        return :set if [left_kind, right_kind].include?(:set)

        :list
      end

      def dedup_if_set(kind, elements)
        return elements unless kind == :set

        seen = []
        elements.reject do |element|
          duplicate = seen.any? { |s| values_equal?(s, element) }
          seen << element
          duplicate
        end
      end

      # Tables 18: difference covers bag and set operands; the right
      # operand may be an element singleton. The result keeps the left
      # operand's kind.
      def aggregate_difference(left, right)
        kind = left.is_a?(V::Aggregate) ? left.kind : right.kind
        unless %i[bag set].include?(kind)
          raise Error,
                "difference requires bag or set operands (12.6, table 18)"
        end

        left_elements = left.is_a?(V::Aggregate) ? left.elements : [left]
        right_elements = right.is_a?(V::Aggregate) ? right.elements : [right]
        remaining = left_elements.reject do |element|
          right_elements.any? { |r| values_equal?(r, element) }
        end
        V::Aggregate.of(kind, remaining)
      end

      # Table 16: intersection covers bag and set operands only;
      # bag∩bag → bag, anything else → set.
      def aggregate_intersection(left, right)
        unless aggregate_pair?(left, right) &&
            %i[bag set].include?(left.kind) &&
            %i[bag set].include?(right.kind)
          raise Error,
                "intersection requires bag or set operands (12.6, table 16)"
        end

        kind = left.kind == :bag && right.kind == :bag ? :bag : :set
        kept = left.elements.select do |element|
          right.elements.any? { |r| values_equal?(r, element) }
        end
        V::Aggregate.of(kind, dedup_if_set(kind, kept))
      end

      def values_equal?(one, other)
        return true if one.equal?(other)
        return false if one.class != other.class

        case one
        when V::Enumeration then one.item == other.item
        when V::Logical then one.value == other.value
        when V::Binary then one.bits == other.bits
        when V::Aggregate
          one.elements.size == other.elements.size &&
            one.elements.zip(other.elements).all? { |x, y| values_equal?(x, y) }
        else one == other
        end
      end

      # ---- indeterminate propagation ----

      def indeterminate?(*values)
        values.any? { |value| value.equal?(V::INDETERMINATE) }
      end

      def describe(value)
        case value
        when V::Logical then "LOGICAL"
        when V::Enumeration then "ENUMERATION"
        when V::Binary then "BINARY"
        when V::Aggregate then "aggregate"
        when String then "string"
        when Numeric then "number"
        else value.equal?(V::INDETERMINATE) ? "?" : value.class.name
        end
      end
    end
  end
end
