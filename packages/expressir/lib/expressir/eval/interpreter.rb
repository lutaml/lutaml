# frozen_string_literal: true

module Expressir
  module Eval
    # Function and statement interpretation (TODO.sota/02 step 2):
    # ISO 10303-11 ch.13 executable statements over the value model,
    # with the pure builtin functions of ch.15 set A (math/string/
    # aggregate). Instance-aware builtins (TYPEOF, USEDIN, EXISTS over
    # instances) arrive with step 3.
    class Interpreter
      V = Expressir::Eval::Values
      EX = Expressir::Eval::Expression

      BUILTIN_CONSTANTS = {
        "PI" => Math::PI,
        "E" => Math::E,
        "CONST_E" => Math::E,
      }.freeze

      def initialize(schema:, population: nil)
        @schema = schema
        @population = population
      end

      def function(name)
        key = name.to_s.safe_downcase
        Array(@schema&.functions).find { |f| f.id&.safe_downcase == key }
      end

      def call(name, arguments)
        function = function(name)
        return execute_function(function, arguments) if function

        call_builtin(name, arguments)
      end

      def execute_function(function, arguments)
        env = Environment.new(schema: @schema, population: @population)
        parameters = Array(function.parameters)
        parameters.each_with_index do |param, index|
          env = env.define(param.id, arguments.fetch(index, V::INDETERMINATE))
        end

        Array(function.variables).each do |variable|
          value = variable.expression ? EX.evaluate(variable.expression, env) : V::INDETERMINATE
          env = env.define(variable.id, value)
        end

        result = catch(:eval_return) do
          execute_statements(function, Array(function.statements), env)
          nil
        end
        return result.first if result.is_a?(Array) && result.size == 1
        return result unless result.nil?

        raise Error, "function '#{function.id}' ended without RETURN (13.7)"
      end

      def execute_statements(owner, statements, env)
        current = env
        Array(statements).each do |statement|
          current = execute_statement(owner, statement, current)
        end
        current
      end

      def execute_statement(owner, statement, env)
        case statement
        when Model::Statements::Null then env
        when Model::Statements::Assignment then execute_assignment(statement, env)
        when Model::Statements::If then execute_if(owner, statement, env)
        when Model::Statements::Case then execute_case(owner, statement, env)
        when Model::Statements::Repeat then execute_repeat(owner, statement, env)
        when Model::Statements::Return then throw(:eval_return, [evaluate_return(statement, env)])
        when Model::Statements::Escape then throw(:eval_escape, env)
        when Model::Statements::Skip then throw(:eval_skip, env)
        when Model::Statements::ProcedureCall
          raise Error, "procedure calls arrive with TODO.sota/02 step 3+"
        when Model::Statements::Alias
          raise Error, "ALIAS statements arrive with TODO.sota/02 step 3+"
        else
          raise Error, "unsupported statement #{statement.class.name}"
        end
      end

      def evaluate_return(statement, env)
        statement.expression ? EX.evaluate(statement.expression, env) : nil
      end

      def execute_assignment(statement, env)
        value = EX.evaluate(statement.expression, env)
        target = statement.ref
        case target
        when Model::References::SimpleReference
          env.define(target.id, value)
        when Model::References::IndexReference
          execute_indexed_assignment(target, value, env)
        else
          raise Error, "assignment to instance attributes requires a " \
                       "population (step 3)"
        end
      end

      def execute_indexed_assignment(target, value, env)
        raise Error, "aggregate element assignment expects one index" if target.index2

        base = target.ref
        unless base.is_a?(Model::References::SimpleReference)
          raise Error, "nested indexed assignment requires a population (step 3)"
        end

        aggregate = env.lookup(base.id)
        unless aggregate.is_a?(V::Aggregate)
          raise Error, "indexed assignment requires an aggregate variable"
        end

        index = EX.evaluate(target.index1, env) - 1
        elements = aggregate.elements.dup
        elements[index] = value
        env.define(base.id, V::Aggregate.of(aggregate.kind, elements))
      end

      def execute_if(owner, statement, env)
        condition = EX.evaluate(statement.expression, env)
        truth = logical_truth(condition)
        branch = truth == V::LOGICAL_TRUE ? statement.statements : statement.else_statements
        execute_statements(owner, Array(branch), env)
      end

      def execute_case(owner, statement, env)
        selector = EX.evaluate(statement.expression, env)
        action = Array(statement.actions).find do |case_action|
          Array(case_action.labels).any? do |label|
            EX.values_equal?(selector, EX.evaluate(label, env))
          end
        end
        body = action ? action.statement : statement.otherwise_statement
        return env unless body

        execute_statement(owner, body, env)
      end

      def execute_repeat(owner, statement, env)
        if statement.while_expression
          execute_while(owner, statement, env)
        elsif statement.until_expression
          execute_until(owner, statement, env)
        else
          execute_increment(owner, statement, env)
        end
      end

      def execute_while(owner, statement, env)
        escaped = catch(:eval_escape) do
          loop do
            condition = EX.evaluate(statement.while_expression, env)
            break unless logical_truth(condition) == V::LOGICAL_TRUE

            env = execute_statements(owner, Array(statement.statements), env)
          end
          nil
        end
        escaped || env
      end

      def execute_until(owner, statement, env)
        escaped = catch(:eval_escape) do
          loop do
            env = execute_statements(owner, Array(statement.statements), env)
            condition = EX.evaluate(statement.until_expression, env)
            break if logical_truth(condition) == V::LOGICAL_TRUE
          end
          nil
        end
        escaped || env
      end

      def execute_increment(owner, statement, env)
        first = EX.evaluate(statement.bound1, env)
        last = EX.evaluate(statement.bound2, env)
        step = statement.increment ? EX.evaluate(statement.increment, env) : 1
        raise Error, "repeat increment must not be zero (13.6.1)" if step.zero?

        control = statement.id
        value = first
        current = env
        escaped = catch(:eval_escape) do
          loop do
            break if step.positive? ? value > last : value < last

            iteration_env = current.define(control, value)
            current = catch(:eval_skip) do
              execute_statements(owner, Array(statement.statements),
                                 iteration_env)
            end || iteration_env
            value += step
          end
          nil
        end
        escaped || current
      end

      # 12.4: only true selects the then-branch; unknown/false/indeterminate
      # take the else branch.
      def logical_truth(value)
        return :unknown if value.equal?(V::INDETERMINATE)

        value.is_a?(V::Logical) ? value.value : :unknown
      end

      # ---- builtin functions (ch.15, set A) ----

      def call_builtin(name, arguments)
        dispatch_builtin(name.to_s.upcase, arguments)
      end

      def dispatch_builtin(name, arguments)
        case name
        when "ABS" then arguments[0].abs
        when "SIN" then Math.sin(arguments[0])
        when "COS" then Math.cos(arguments[0])
        when "TAN" then Math.tan(arguments[0])
        when "ASIN" then Math.asin(arguments[0])
        when "ACOS" then Math.acos(arguments[0])
        when "ATAN" then Math.atan(arguments[0])
        when "ATAN2" then Math.atan2(arguments[0], arguments[1])
        when "SQRT" then Math.sqrt(arguments[0])
        when "EXP" then Math.exp(arguments[0])
        when "LOG" then Math.log(arguments[0])
        when "LOG2" then Math.log2(arguments[0])
        when "LOG10" then Math.log10(arguments[0])
        when "ODD" then V::Logical.new(value: arguments[0].odd? ? V::LOGICAL_TRUE : V::LOGICAL_FALSE)
        when "LENGTH" then arguments[0].to_s.length
        when "BLENGTH" then arguments[0].bits.length
        when "SIZEOF", "HIINDEX", "HIBOUND" then arguments[0].elements.size
        when "LOINDEX", "LOBOUND" then 1
        when "EXISTS" then V::Logical.new(value: exists?(arguments[0]) ? V::LOGICAL_TRUE : V::LOGICAL_FALSE)
        when "TYPEOF" then typeof_value(arguments[0])
        when "USEDIN" then usedin_value(arguments[0], arguments[1])
        when "NVL"
          arguments[0].equal?(V::INDETERMINATE) ? arguments[1] : arguments[0]
        when "BOUNDS"
          # 15.6 over evaluated aggregates: the LOINDEX..HIBOUND pair
          V::Aggregate.of(:list, [1, arguments[0].elements.size])
        when "ROLESOF"
          # 15.21: no role metadata in the evaluated population — the
          # empty set (D-06)
          V::Aggregate.of(:set, [])
        when "VALUE_IN"
          # 15.29: membership of a value in an aggregate of values
          present = Array(arguments[1].elements).any? do |candidate|
            EX.values_equal?(candidate, arguments[0])
          end
          V::Logical.new(value: present ? V::LOGICAL_TRUE : V::LOGICAL_FALSE)
        when "VALUE"
          return arguments[0] if arguments[0].is_a?(Numeric)

          text = arguments[0].to_s
          text.match?(/\A[+-]?\d+\z/) ? text.to_i : text.to_f
        else
          raise Error, "builtin '#{name}' is not implemented yet"
        end
      end

      def exists?(value)
        !value.equal?(V::INDETERMINATE) && !value.nil?
      end

      # TYPEOF (15.x): the type names of an instance — the record
      # keyword plus its supertype closure, unqualified and
      # schema-qualified (corpus rules use the qualified form).
      def typeof_value(value)
        return V::Aggregate.of(:set, []) unless value.is_a?(V::Instance)

        keywords = if value.record.is_a?(Expressir::P21::ComplexRecord)
                     Array(value.record.records).map(&:keyword)
                   else
                     [value.record.keyword]
                   end
        names = keywords.flat_map { |keyword| typeof_names(keyword) }
        V::Aggregate.of(:set, names.uniq)
      end

      def typeof_names(keyword)
        entity = Array(@schema&.entities).find do |candidate|
          candidate.id&.safe_downcase == keyword&.safe_downcase
        end
        return [keyword.to_s.upcase] unless entity

        ([entity] + entity.supertype_closure).flat_map do |candidate|
          [candidate.id.upcase, "#{@schema.id.upcase}.#{candidate.id.upcase}"]
        end.uniq
      end

      # USEDIN (15.x): instances that reference the argument.
      def usedin_value(value, _role)
        return V::Aggregate.of(:bag, []) unless
          value.is_a?(V::Instance) && @population

        referencing = @population.instances.filter_map do |id, record|
          next unless record_references?(record, value.id)

          V::Instance.new(id: id.delete_prefix("#"), record: record)
        end
        V::Aggregate.of(:bag, referencing)
      end

      def record_references?(record, target_id)
        records = record.is_a?(Expressir::P21::ComplexRecord) ? record.records : [record]
        reference = "##{target_id}"
        records.any? do |partial|
          params_reference?(partial.params, reference)
        end
      end

      def params_reference?(params, reference)
        Array(params).any? do |param|
          case param
          when String then param == reference
          when Array then params_reference?(param, reference)
          when Expressir::P21::TypedValue
            params_reference?(param.value, reference)
          else false
          end
        end
      end
    end
  end
end
