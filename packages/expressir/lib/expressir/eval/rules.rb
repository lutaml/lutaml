# frozen_string_literal: true

module Expressir
  module Eval
    # WHERE-rule checking over a population (TODO.sota/02 step 4):
    # every instance's entity domain rules evaluate with SELF and the
    # entity's attributes bound. Per ISO 10303-11 9.4 a rule is
    # violated only when it evaluates to false; unknown/indeterminate
    # is not a violation.
    module Rules
      V = Expressir::Eval::Values
      EX = Expressir::Eval::Expression

      RuleResult = Struct.new(:instance, :rule_id, :status, :message,
                              keyword_init: true)

      module_function

      def check(population, schema)
        population.instances.flat_map do |id, record|
          entity = entity_for(schema, record)
          next [] unless entity

          Array(entity.where_rules).map do |rule|
            evaluate_rule(population, schema, id, record, entity, rule)
          end
        end
      end

      def failures(results)
        results.select { |result| result.status == :fail }
      end

      def violated?(results)
        failures(results).any?
      end

      def evaluate_rule(population, schema, id, record, entity, rule)
        env = environment_for(population, schema, id, record, entity)
        value = EX.evaluate(rule.expression, env)
        status = status_of(value)
        RuleResult.new(
          instance: id,
          rule_id: rule.id,
          status: status,
          message: status == :fail ? "#{id}: #{entity.id}.#{rule.id}" : nil,
        )
      rescue Expressir::Eval::Error => e
        RuleResult.new(instance: id, rule_id: rule.id, status: :error,
                       message: "#{id}: #{entity.id}.#{rule.id}: #{e.message}")
      end

      def environment_for(population, schema, id, record, entity)
        env = Environment.new(schema: schema, population: population)
        instance = V::Instance.new(id: id.delete_prefix("#"), record: record)
        env = env.define("self", instance)
        env.slots_for(entity).each_key do |name|
          next unless name

          value = EX.instance_attribute(instance, name, env)
          env = env.define(name, value)
        end
        env
      end

      def status_of(value)
        return :unknown if value.equal?(V::INDETERMINATE)
        return :unknown unless value.is_a?(V::Logical)

        case value.value
        when V::LOGICAL_TRUE then :pass
        when V::LOGICAL_FALSE then :fail
        else :unknown
        end
      end

      def entity_for(schema, record)
        if record.is_a?(Expressir::P21::ComplexRecord)
          record = record.records.first
        end
        Array(schema.entities).find do |entity|
          entity.id&.safe_downcase == record.keyword&.safe_downcase
        end
      end
    end
  end
end
