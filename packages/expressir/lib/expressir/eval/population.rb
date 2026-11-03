# frozen_string_literal: true

module Expressir
  module Eval
    # Population-scale rule engine (TODO.instance/02). Each rule
    # resolves once per schema edition and applies to many instances.
    # Entity WHERE rules scope over the entity and its subtypes
    # (ISO 10303-11 9.2.1, applicability via P21::Typing); UNIQUE
    # rules (9.2.2.1) compare value tuples across the whole
    # population; global rules (9.4) evaluate once per rule with the
    # FOR entities bound to their instance aggregates. Per 9.4 a rule
    # is violated only when it evaluates to false.
    class Population
      Finding = Struct.new(:kind, :instance, :rule_id, :message,
                           keyword_init: true)

      attr_reader :schema, :population, :typing

      def self.check(schema, population, short_names: nil)
        new(schema, population, short_names: short_names).check
      end

      def initialize(schema, population, short_names: nil)
        @schema = schema
        @population = population
        @typing = P21::Typing.new(schema, short_names: short_names)
        @by_entity = nil
        @slots = {}
      end

      def check
        where_findings + unique_findings + global_findings
      end

      # Instances conforming to the named entity, including subtypes.
      def instances_for(entity)
        by_entity[entity.id&.safe_downcase] || []
      end

      private

      def by_entity
        @by_entity ||= begin
          index = Hash.new { |hash, key| hash[key] = [] }
          @population.instances.each do |id, record|
            @typing.of(record).each do |entity|
              index[entity.id&.safe_downcase] << [id, record]
            end
          end
          index
        end
      end

      def where_findings
        @schema.entities.flat_map do |entity|
          rules = Array(entity.where_rules)
          next [] if rules.empty?

          instances_for(entity).flat_map do |(id, record)|
            rules.filter_map do |rule|
              where_finding(id, record, entity, rule)
            end
          end
        end
      end

      def where_finding(id, record, entity, rule)
        env = Rules.environment_for(@population, @schema, id, record, entity)
        value = Expression.evaluate(rule.expression, env)
        return unless false?(value)

        Finding.new(kind: :where, instance: id, rule_id: rule.id,
                    message: "#{id}: #{entity.id}.#{rule.id} (9.4)")
      rescue Expressir::Eval::Error => e
        Finding.new(kind: :where, instance: id, rule_id: rule.id,
                    message: "#{id}: #{entity.id}.#{rule.id}: #{e.message}")
      end

      def unique_findings
        @schema.entities.flat_map do |entity|
          Array(entity.unique_rules).flat_map do |rule|
            unique_rule_findings(entity, rule)
          end
        end
      end

      # 9.2.2.1: the value tuple of the referenced attributes must be
      # unique across all instances of the entity and its subtypes.
      def unique_rule_findings(entity, rule)
        seen = {}
        instances_for(entity).filter_map do |(id, record)|
          env = Rules.environment_for(@population, @schema, id, record,
                                      entity)
          instance = Values::Instance.new(id: id.delete_prefix("#"),
                                          record: record)
          key = unique_key(rule, entity, env, instance)
          if key.nil?
            next error_finding(:unique, id, rule.id,
                               "#{id}: UNIQUE '#{rule.id}' references an " \
                               "attribute outside '#{entity.id}' (9.2.2.1)")
          end

          first = seen[key]
          seen[key] = id
          next unless first

          Finding.new(kind: :unique, instance: id, rule_id: rule.id,
                      message: "#{id}: UNIQUE '#{rule.id}' duplicates " \
                               "#{first} (9.2.2.1)")
        end
      end

      def unique_key(rule, entity, env, instance)
        Array(rule.attributes).map do |reference|
          name = reference.respond_to?(:id) ? reference.id : reference.to_s
          return nil unless slots_for(entity).key?(name.safe_downcase)

          Expression.instance_attribute(instance, name, env).inspect
        end
      end

      def slots_for(entity)
        @slots[entity] ||= Environment.new(schema: @schema).slots_for(entity)
      end

      # 9.4 global rules: the FOR entities are bound, in the rule's
      # scope, to the aggregates of all their instances.
      def global_findings
        Array(@schema.rules).flat_map do |rule|
          env = global_environment(rule)
          if env.nil?
            next [error_finding(:global, nil, rule.id,
                                "global rule '#{rule.id}' names no entity " \
                                "(9.4)")]
          end

          Array(rule.where_rules).filter_map do |where|
            value = Expression.evaluate(where.expression, env)
            next unless false?(value)

            Finding.new(kind: :global, instance: nil, rule_id: rule.id,
                        message: "global rule '#{rule.id}' (9.4)")
          rescue Expressir::Eval::Error => e
            error_finding(:global, nil, rule.id,
                          "global rule '#{rule.id}': #{e.message}")
          end
        end
      end

      def global_environment(rule)
        env = Environment.new(schema: @schema, population: @population)
        bound = 0
        Array(rule.applies_to).each do |reference|
          name = reference.respond_to?(:id) ? reference.id : nil
          entity = name && @schema.entities.find do |candidate|
            candidate.id&.safe_downcase == name.safe_downcase
          end
          return nil unless entity

          env = env.define(
            name.safe_downcase,
            Values::Aggregate.of(
              :list, instances_for(entity).map do |(id, record)|
                Values::Instance.new(id: id.delete_prefix("#"), record: record)
              end
            ),
          )
          bound += 1
        end
        bound.positive? ? env : nil
      end

      def error_finding(kind, instance, rule_id, message)
        Finding.new(kind: kind, instance: instance, rule_id: rule_id,
                    message: message)
      end

      def false?(value)
        return true if value == Values::LOGICAL_FALSE
        return value.value == Values::LOGICAL_FALSE if value.is_a?(Values::Logical)

        false
      end
    end
  end
end
