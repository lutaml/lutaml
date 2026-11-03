# frozen_string_literal: true

module Expressir
  module P21
    # ISO 10303-11 9.2.5 instance typing: which entities a Part 21
    # instance conforms to. A simple record conforms to its keyword
    # entity plus that entity's supertype closure; a complex record
    # conforms to the union of its records' closures. ONEOF
    # exclusivity (9.2.5.2) is reported per complex record.
    class Typing
      Result = Struct.new(:entities, :issues, keyword_init: true)

      def initialize(schema, short_names: nil)
        @schema = schema
        @short_names = short_names&.transform_keys(&:downcase)
        @results = {}.compare_by_identity
      end

      def of(record)
        result(record).entities
      end

      def issues(record)
        result(record).issues
      end

      def result(record)
        @results[record] ||= compute(record)
      end

      private

      def compute(record)
        parts = record.is_a?(ComplexRecord) ? record.records : [record]
        entities = []
        leaves = []
        issues = []
        seen_leaves = {}
        parts.each do |part|
          entity = Validator.find_entity(@schema, part.keyword, @short_names)
          if entity.nil?
            issues << "keyword '#{part.keyword}' is not declared in " \
                      "schema '#{@schema.id}'"
            next
          end

          key = entity.id&.safe_downcase
          if seen_leaves[key]
            issues << "complex instance instantiates '#{entity.id}' " \
                      "twice (9.2.5)"
          end
          seen_leaves[key] = true
          leaves << entity
          entities.push(entity, *entity.supertype_closure)
        end
        issues.concat(oneof_issues(leaves))
        entities.uniq! { |entity| entity.id&.safe_downcase }
        Result.new(entities: entities, issues: issues)
      end

      def oneof_issues(leaves)
        leaves.combination(2).filter_map do |left, right|
          next unless shared_oneof_group?(left, right)

          "complex instance combines '#{left.id}' and '#{right.id}' " \
            "in one ONEOF group (9.2.5.2)"
        end
      end

      def shared_oneof_group?(left, right)
        oneof_groups(left).any? do |group|
          group.include?(left.id&.safe_downcase) &&
            group.include?(right.id&.safe_downcase)
        end
      end

      # ONEOF groups constraining an entity: its own supertype
      # expression, every supertype's expression, and the ONEOF
      # subtype constraints applied to any of them (9.7).
      def oneof_groups(entity)
        @oneof_groups ||= {}
        key = entity.id&.safe_downcase
        @oneof_groups[key] ||= begin
          groups = []
          [entity, *entity.supertype_closure].each do |supertype|
            expression = supertype.supertype_expression
            groups << oneof_members(expression) if oneof?(expression)
            subtype_constraint_groups(supertype, groups)
          end
          groups
        end
      end

      def subtype_constraint_groups(supertype, groups)
        Array(@schema.subtype_constraints).each do |constraint|
          next unless constraint.applies_to&.id&.safe_downcase == supertype.id&.safe_downcase

          expression = constraint.supertype_expression
          groups << oneof_members(expression) if oneof?(expression)
        end
      end

      def oneof?(expression)
        expression.is_a?(Model::SupertypeExpressions::OneofSupertypeExpression)
      end

      def oneof_members(expression)
        Array(expression.operands).filter_map do |operand|
          next unless operand.respond_to?(:id) && operand.id

          operand.id.safe_downcase
        end
      end
    end
  end
end
