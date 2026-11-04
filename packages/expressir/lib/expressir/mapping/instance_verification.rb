# frozen_string_literal: true

module Expressir
  module Mapping
    # ARM↔MIM instance mapping verification (TODO.instance/04): given
    # a module's mapping tables (Mapping::Document) and two
    # populations — an ARM-typed one and a MIM one — verify the MIM
    # population is the image of the ARM population. Each application
    # element is an instance predicate: every ARM instance of the
    # element's entity must have a MIM image whose typing includes the
    # mapped MIM entity, whose element refpath (or an alt_map route)
    # resolves from that image, whose attribute-mapping refpaths
    # terminate at values equal to the ARM attribute values, and whose
    # inline element rules evaluate true (Eval WHERE semantics, self
    # bound to the image).
    #
    # Reference values correspond across the two populations through
    # the mapping itself: an ARM `#n` terminal matches the MIM image
    # of ARM instance n under the element that maps its keyword.
    #
    # Instance-level path walking covers the mapping-corpus RefPath
    # constructs: bare and attribute-qualified nodes, `->`/`<-`
    # navigation, `<=`/`=>` restatements, the §5 `||supertype||` and
    # `*tree*` markers, and `{entity.attr = literal}` constraints
    # (with `!` negation). Rules fields that name global rules rather
    # than inline expressions are the domain of Mapping.rule_issues;
    # they are not re-checked per instance here. Complex (multi-role)
    # records are outside v1 scope: a complex candidate fails its
    # route rather than silently passing.
    class InstanceVerification
      Finding = Struct.new(:arm_instance, :entity, :message, keyword_init: true)

      # Part 21 value normalization for equality: enumerations compare
      # by name, typed parameters by keyword+value.
      module ValueCompare
        module_function

        def comparable(value)
          case value
          when P21::Enumeration then value.name
          when P21::TypedValue then [value.keyword, comparable(value.value)]
          when Array then value.map { |item| comparable(item) }
          else value
          end
        end
      end

      include ValueCompare

      attr_reader :findings

      def initialize(mapping:, arm_schema:, mim_schema:,
                     arm_population:, mim_population:)
        @mapping = mapping
        @arm_schema = arm_schema
        @mim_schema = mim_schema
        @arm_population = arm_population
        @mim_population = mim_population
        @arm_typing = P21::Typing.new(arm_schema)
        @mim_typing = P21::Typing.new(mim_schema)
        @arm_slots = Eval::Environment.new(schema: arm_schema)
        @mim_slots = Eval::Environment.new(schema: mim_schema)
        @findings = []
        @image_cache = {}
        @rule_cache = {}
      end

      def verify
        @mapping.ae.to_a.each { |element| verify_element(element) }
        @findings
      end

      private

      def verify_element(element)
        arm_entity = find_entity(@arm_schema, element.entity)
        unless arm_entity
          @findings << Finding.new(arm_instance: nil, entity: element.entity,
                                   message: "ARM schema declares no entity " \
                                            "'#{element.entity}'")
          return
        end

        arm_instances(arm_entity).each do |(id, record)|
          next if image_of(element, record, id, {}.compare_by_identity)

          @findings << Finding.new(
            arm_instance: id, entity: element.entity,
            message: "no MIM image of #{element.entity} instance #{id} " \
                     "through the mapping"
          )
        end
      end

      def arm_instances(entity)
        @arm_population.instances.filter_map do |id, record|
          next unless typed?(@arm_typing, record, entity)

          [id, record]
        end
      end

      # The MIM image id of one ARM instance, or nil. Tries the
      # element's primary route then each alt_map route; memoized so
      # cross-population reference correspondence stays linear.
      def image_of(element, arm_record, arm_id, seen)
        key = [element.object_id, arm_id]
        return @image_cache[key] if @image_cache.key?(key)
        return nil if seen[arm_id]

        seen[arm_id] = true
        @image_cache[key] = routes(element).filter_map do |route|
          mim_entity = find_entity(@mim_schema, route[:entity])
          next unless mim_entity

          mim_candidates(mim_entity).find do |(mim_id, mim_record)|
            route_matches?(route, element, arm_record,
                           arm_entity_of(element), mim_id, mim_record,
                           mim_entity, seen)
          end&.first
        end.first
      end

      def routes(element)
        [{ entity: Mapping.entity_item(element.aimelt),
           path: element.refpath&.content }].concat(
             element.alt_map.to_a.map do |alt|
               { entity: Mapping.entity_item(alt.aimelt),
                 path: alt.refpath&.content }
             end,
           ).reject { |route| route[:entity].nil? || route[:entity].empty? }
      end

      def route_matches?(route, element, arm_record, arm_entity,
                         mim_id, mim_record, mim_entity, seen)
        walk = Walker.new(@mim_population, @mim_typing, @mim_slots, @mim_schema)
        walk.follow(route[:path], mim_id, mim_record, mim_entity) if route[:path]
        element.aa.to_a.all? do |aa|
          attribute_matches?(aa, arm_record, arm_entity,
                             mim_id, mim_record, mim_entity, seen)
        end && rules_hold?(element, mim_entity, mim_id, mim_record)
      rescue Walker::BrokenPath
        false
      end

      def attribute_matches?(attr_mapping, arm_record, arm_entity,
                             mim_id, mim_record, mim_entity, seen)
        arm_value = arm_attribute_value(arm_record, arm_entity, attr_mapping)
        walk = Walker.new(@mim_population, @mim_typing, @mim_slots, @mim_schema)
        walk.follow(attr_mapping.refpath&.content, mim_id, mim_record, mim_entity)
        values_match?(walk.terminal, arm_value, seen)
      rescue Walker::BrokenPath
        false
      end

      def values_match?(mim_value, arm_value, seen)
        comparable(mim_value) == comparable(arm_value) ||
          reference_corresponds?(mim_value, arm_value, seen)
      end

      # Reference values correspond through the mapping: the ARM `#n`
      # must map to exactly the MIM instance the path reached.
      def reference_corresponds?(mim_value, arm_value, seen)
        return false unless reference?(mim_value) && reference?(arm_value)

        arm_record = @arm_population.instances[arm_value]
        return false unless arm_record

        element = @mapping.ae.to_a.find do |ae|
          ae.entity&.safe_downcase == arm_record.keyword&.safe_downcase
        end
        return false unless element

        image_of(element, arm_record, arm_value, seen) == mim_value
      end

      def reference?(value)
        value.is_a?(String) && value.start_with?("#")
      end

      def arm_attribute_value(arm_record, arm_entity, attr_mapping)
        name = attr_mapping.attribute.to_s.split(".").last
        index = @arm_slots.slots_for(arm_entity)[name&.safe_downcase]
        raise Walker::BrokenPath, "ARM entity has no attribute '#{name}'" unless index

        arm_record.params[index]
      end

      # Inline expression rules are instance predicates; a rules field
      # that is not an expression (a named global rule) is left to
      # Mapping.rule_issues.
      def rules_hold?(element, mim_entity, mim_id, mim_record)
        content = element.rules&.content
        return true unless content

        expression = @rule_cache[content] ||= parse_rule_expression(content)
        return true unless expression

        env = Eval::Rules.environment_for(@mim_population, @mim_schema,
                                          mim_id, mim_record, mim_entity)
        !logical_false?(Eval::Expression.evaluate(expression, env))
      rescue Eval::Error, Walker::BrokenPath
        false
      end

      def parse_rule_expression(content)
        parsed = Expressir::Express::Parser.from_exp(
          "SCHEMA mapping_rule_wrap; ENTITY wrap; " \
          "WHERE rule_expr : #{content}; END_ENTITY; END_SCHEMA;",
        )
        parsed.schemas.first.entities.first.where_rules.first.expression
      rescue StandardError
        nil
      end

      def logical_false?(result)
        return [false, Eval::Values::LOGICAL_FALSE].include?(result) unless
          result.is_a?(Eval::Values::Logical)

        result.value == Eval::Values::LOGICAL_FALSE
      end

      def mim_candidates(entity)
        @mim_population.instances.filter_map do |id, record|
          next unless typed?(@mim_typing, record, entity)

          [id, record]
        end
      end

      def typed?(typing, record, entity)
        typing.issues(record).empty? &&
          typing.of(record)
            .any? { |decl| decl.id&.safe_downcase == entity.id&.safe_downcase }
      end

      def arm_entity_of(element)
        find_entity(@arm_schema, element.entity)
      end

      def find_entity(schema, name)
        key = Mapping.entity_item(name).to_s.safe_downcase
        Array(schema.entities).find { |entity| entity.id&.safe_downcase == key }
      end

      # Walks a reference path through actual population instances,
      # starting at a candidate MIM image. Raises BrokenPath the
      # moment the population contradicts the path.
      class Walker
        class BrokenPath < StandardError
        end

        include ValueCompare

        attr_reader :terminal

        def initialize(population, typing, slots, schema)
          @population = population
          @typing = typing
          @slots = slots
          @schema = schema
        end

        def follow(content, id, record, entity)
          @id = id
          @record = record
          @entity = entity
          @last_attr = nil
          @terminal = nil
          RefPath.parse(content).steps.each { |step| follow_step(step) } if content
          self
        end

        private

        def follow_step(step)
          return if marker_step?(step)
          return constraint(step) if step.operator == "{"
          return move_to(step.name) if step.name && %w[<= => || = *].include?(step.operator)
          return navigate(step) if step.operator == "->"
          return inverse(step) if step.operator == "<-"
          return step_over(step) if step.name

          raise BrokenPath, "unsupported path step '#{step.operator}'"
        end

        def marker_step?(step)
          step.name.nil? && step.attribute.nil? && step.link.nil? &&
            step.operator != "{" && step.operator != "(" && step.operator != ")"
        end

        # {entity.attr = literal} against the instance the walk sits
        # on; `!{` negates.
        def constraint(step)
          unless step.name.nil? ||
              step.name&.safe_downcase == @entity&.id&.safe_downcase
            raise BrokenPath,
                  "constraint on '#{step.name}' does not name the " \
                  "walk's entity"
          end
          return unless step.attribute

          actual = read(step.attribute)
          expected = step.literal.to_s
          expected = expected[1..-2] if expected.start_with?("'")
          holds = comparable(actual).to_s.casecmp?(expected)
          holds = !holds if step.negated
          return if holds

          raise BrokenPath,
                "constraint '#{step.name}.#{step.attribute} = " \
                "#{step.literal}' does not hold"
        end

        # The instance must conform to the named declaration; the walk
        # context moves there so later slots resolve against it.
        def move_to(name)
          target = find_entity(name)
          raise BrokenPath, "no declaration '#{name}'" unless target

          conforms = @typing.of(@record)
            .any? { |decl| decl.id&.safe_downcase == target.id&.safe_downcase }
          raise BrokenPath, "instance does not conform to '#{name}'" unless conforms

          @entity = target
        end

        # A bare or attribute-qualified node: restatement plus, when
        # qualified, the attribute read — the terminal value, and the
        # attribute a following `->` navigates through.
        def step_over(step)
          move_to(step.name)
          @last_attr = step.attribute
          @terminal = read(step.attribute) if step.attribute
        end

        # `attr -> entity`: the recorded attribute must hold a
        # reference to an instance of the named entity.
        def navigate(step)
          attribute = step.attribute || @last_attr
          raise BrokenPath, "'->' without an attribute" unless attribute

          value = read(attribute)
          target = @population.instances[value.to_s]
          raise BrokenPath, "'#{attribute}' does not hold a reference" unless target

          @record = target
          @id = value.to_s
          move_to(step.name)
          @last_attr = nil
        end

        # `<- entity.attr`: some instance of the named entity must
        # reference the current one through the attribute; the walk
        # moves there.
        def inverse(step)
          raise BrokenPath, "'<-' without an attribute" unless step.attribute

          found = @population.instances.find do |_, candidate|
            keyword = candidate.keyword&.safe_downcase
            next false unless keyword == step.name&.safe_downcase

            read_attribute(candidate, step.attribute) == @id
          end
          unless found
            raise BrokenPath,
                  "no '#{step.name}' instance references '#{@id}' " \
                  "through '#{step.attribute}'"
          end

          @record = found[1]
          @id = found[0]
          move_to(step.name)
          @last_attr = step.attribute
        end

        def read(attribute)
          read_attribute(@record, attribute, entity: @entity)
        end

        def read_attribute(record, attribute, entity: nil)
          target = entity || entity_for_record(record)
          index = @slots.slots_for(target)[attribute&.safe_downcase]
          unless index
            raise BrokenPath,
                  "no attribute '#{attribute}' on '#{target&.id}'"
          end
          raise BrokenPath, "complex records are outside v1 scope" if
            record.is_a?(P21::ComplexRecord)

          record.params[index]
        end

        def entity_for_record(record)
          find_entity(record.keyword)
        end

        def find_entity(name)
          key = name&.safe_downcase
          Array(@schema.entities).find { |entity| entity.id&.safe_downcase == key }
        end
      end
    end
  end
end
