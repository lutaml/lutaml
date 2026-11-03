# frozen_string_literal: true

module Expressir
  module Express
    # SHTOLO — short-to-long conversion per ISO 10303-11:2004 Annex G
    # (expressir#32): flattens a multi-schema specification into a
    # single ISO 10303-11:1994 longform schema.
    #
    # Two stages (annex-g-rules.md):
    #  G.1  multi-schema → intermediate `artifact` schema: interface
    #       closure copied as local declarations, renames resolved to
    #       original names, name clashes munged (G.NM.1), REFERENCE
    #       entities kept with the dependent-instantiability rule
    #       (G.1.6), select/rules/supertype expressions pruned (G.1.9).
    #  G.2  artifact → `longform`: extensible enums/selects resolved
    #       (G.2.3/G.2.4), subtype constraints eliminated (supertype
    #       expression → SUPERTYPE, total_over → rule, G.2.5), abstract
    #       entity → ABSTRACT SUPERTYPE, GENERIC_ENTITY → GENERIC,
    #       RENAMED → DERIVE (G.2.7), qualified strings rewritten.
    #
    # The output is a Model::Declarations::Schema named per the root
    # schema; format it with the Formatter to obtain the longform file.
    class Shtolo
      DEPENDENT_RULE_NAME = "validate_dependently_instantiable_entity_data_types"
      DEPENDENT_FN_NAME = "dependently_instantiated"

      attr_reader :longform, :renames, :schema

      # `root_schema` — the resolved root schema node.
      # `repository`  — must hold the full interface closure.
      # `extenders`   — :all (default, the WG12 requirement) folds every
      #                 extensible SELECT/ENUMERATION extension found in the
      #                 closure into its base type (Annex G.2.3/G.2.4);
      #                 :none leaves extensible types exactly as declared —
      #                 the shape eengine's default --flat emits.
      # `prune`        — true (default) runs the G.1.9 prune pass;
      #                 false keeps the artifact's full declaration set.
      # `stage`        — :longform (default) runs the G.2 rewrites;
      #                 :artifact stops after stage 1 — the annex's
      #                 intermediate schema, the shape eengine's
      #                 --concat_schema output corresponds to (copy
      #                 pass, no prune, no 1994 rewrite).
      def initialize(root_schema, repository, longform_name: nil,
                     extenders: :all, prune: true, stage: :longform)
        @root = root_schema
        @repository = repository
        @longform_name = longform_name || @root.id
        @extenders = extenders
        @prune = prune
        @stage = stage
        @reference_entities = [] # G.1.6 entities
      end

      def flatten
        @schema = build_longform
        self
      end

      IdPlan = Struct.new(:global, :own_by_schema, keyword_init: true) do
        def own(schema)
          own_by_schema[schema] || {}
        end
      end

      private

      # ---- interface closure (same semantics as Concatenator) ----

      def closure
        @closure ||= begin
          by_name = @repository.schemas.to_h { |s| [s.id.safe_downcase, s] }
          visited = {}
          queue = [@root]
          until queue.empty?
            schema = queue.shift
            key = schema.id.safe_downcase
            next if visited.key?(key)

            visited[key] = schema
            Array(schema.interfaces).each do |iface|
              name = iface.schema.is_a?(String) ? iface.schema : iface.schema&.id
              next unless name

              target = by_name[name.safe_downcase]
              queue << target if target && !visited.key?(name.safe_downcase)
            end
          end
          visited
        end
      end

      # ---- G.1 stage 1 ----

      # Two-phase copy: plan every declaration's final id across the whole
      # closure FIRST (G.NM.1 clashes are only known once every schema has
      # been seen), then copy+rewrite each declaration against the complete
      # map. Rewriting as we copy left stale references in declarations
      # copied before a later clash was munged.
      def build_artifact
        schemas = [@root, *closure.values.reject { |s| s.equal?(@root) }]
        plan = plan_ids(schemas)

        declarations = []
        schemas.each do |schema|
          rename_map = renames_for(schema)
          # Resolution order for a reference in this schema: its own local
          # declarations (which may be munged), then interface aliases
          # resolved through the referenced declaration's final id, then
          # the global munge map for names the schema doesn't declare.
          full = plan.global.dup
          plan.own(schema).each { |k, final| full[k] = final }
          rename_map.each do |alias_name, original|
            resolved = plan.own(schema)[original.safe_downcase] ||
              plan.global[original.safe_downcase] || original
            full[alias_name.safe_downcase] = resolved
          end

          all_decls(schema).each do |decl|
            copy = deep_copy(decl)
            rewrite_references(copy, full)
            if decl.respond_to?(:id) && decl.id &&
                (final = plan.own(schema)[decl.id.safe_downcase])
              copy.id = final
            end
            declarations << copy
          end

          # G.1.2: interfaces themselves dissolve; REFERENCE entities
          # keep dependent-instantiability semantics (G.1.6).
          schema.interfaces.each do |iface|
            next unless iface.kind == Model::Declarations::Interface::REFERENCE

            iface_schema = iface.schema.is_a?(String) ? iface.schema : iface.schema&.id
            target = closure[iface_schema&.safe_downcase]
            iface.items.each do |item|
              original = original_name(item, schema)
              next unless target&.entities&.find do |e|
                e.id.safe_downcase == original.safe_downcase
              end

              @reference_entities << original.safe_downcase
            end
          end
        end

        declarations.concat(build_dependent_declarations) if @reference_entities.any?

        Model::Declarations::Schema.new(
          id: @longform_name,
          version: nil,
          interfaces: [],
          constants: declarations.grep(Model::Declarations::Constant).compact,
          types: declarations.grep(Model::Declarations::Type).compact,
          entities: declarations.grep(Model::Declarations::Entity).compact,
          subtype_constraints: declarations.grep(Model::Declarations::SubtypeConstraint).compact,
          functions: declarations.grep(Model::Declarations::Function).compact,
          procedures: declarations.grep(Model::Declarations::Procedure).compact,
          rules: declarations.grep(Model::Declarations::Rule).compact,
        )
      end

      def all_decls(schema)
        schema.constants + schema.types + schema.entities +
          schema.subtype_constraints + schema.functions +
          schema.rules + schema.procedures
      end

      # G.NM.1: the first schema in closure order to declare a name keeps
      # it; every later declaration of the same name is prefixed with ITS
      # OWN schema's id, and the global map redirects the bare name so
      # declarations from third schemas resolve to the first occurrence.
      def plan_ids(schemas)
        # G.NM.1: EVERY clashing declaration is prefixed (the annex
        # example munges farming_dot_dog AND pet_shows_dot_dog), so the
        # clash set is computed over the whole population first.
        counts = Hash.new(0)
        schemas.each do |schema|
          all_decls(schema).each do |decl|
            next unless decl.respond_to?(:id) && decl.id

            counts[decl.id.safe_downcase] += 1
          end
        end

        global = {}          # downcase id => munged final
        own_by_schema = {}   # schema => {downcase id => final id}
        schemas.each do |schema|
          own = {}
          all_decls(schema).each do |decl|
            next unless decl.respond_to?(:id) && decl.id

            key = decl.id.safe_downcase
            own[key] = if counts[key] > 1
                         global[key] = "#{schema.id.safe_downcase}_dot_#{decl.id}"
                       else
                         decl.id
                       end
          end
          own_by_schema[schema] = own
        end
        IdPlan.new(global: global, own_by_schema: own_by_schema)
      end

      # Alias → original map applied when copying `schema`'s
      # declarations: the aliases are declared by the schema's own
      # interface items (`USE FROM s (orig AS alias)`, G.1.3).
      def renames_for(schema)
        map = {}
        Array(schema.interfaces).each do |iface|
          iface.items.each do |item|
            original = item.ref.is_a?(String) ? item.ref : item.ref&.id
            next unless original

            map[item.id.safe_downcase] = original if item.id &&
              item.id.safe_downcase != original.safe_downcase
          end
        end
        map
      end

      def original_name(item, schema)
        original = item.ref.is_a?(String) ? item.ref : item.ref&.id
        return schema.id unless original

        original
      end

      def deep_copy(obj)
        sever = []
        node = obj
        while node.respond_to?(:parent) && node.parent
          sever << node
          node = node.parent
        end
        saved = sever.map(&:parent)
        sever.each { |n| n.parent = nil }
        Marshal.load(Marshal.dump(obj))
      ensure
        sever.each_with_index { |n, i| n.parent = saved[i] }
      end

      # Rewrite SimpleReference ids against a rename map in ONE tree walk
      # (each declaration is walked once, whatever the map's size — walking
      # once per rename made flattening quadratic in the closure).
      # Map keys are downcased old names, values the final names.
      def rewrite_references(node, map)
        return unless node.is_a?(Model::ModelElement)

        if node.is_a?(Model::References::SimpleReference) && node.id &&
            (to = map[node.id.safe_downcase])
          node.id = preserve_case(node.id, to)
        end
        node.class.attributes.each_key do |attr|
          next if Model::ModelElement::SKIP_ATTRIBUTES.include?(attr) || attr == :parent

          value = node.public_send(attr)
          case value
          when Array then value.each { |item| rewrite_references(item, map) }
          when Model::ModelElement then rewrite_references(value, map)
          end
        end
      end

      def preserve_case(current, new)
        current == current.upcase ? new.upcase : new
      end

      # G.1.6: parse-templates keep the annex rule/function verbatim;
      # the pair is emitted together (the rule's WHERE calls the
      # function, and the prune pass would drop an uncalled function).
      def build_dependent_declarations
        snippet = parse_schema_snippet(dependent_template_src)
        rule = snippet.schemas.first.rules.first
        fn = snippet.schemas.first.functions.first
        [rule, fn].compact
      end

      def dependent_template_src
        list = @reference_entities.map(&:upcase).join(", ")
        union = @reference_entities.join("+")
        <<~EXP
          SCHEMA __dependent__;
          RULE #{DEPENDENT_RULE_NAME} FOR (#{list});
          LOCAL
            number_of_input_instances : INTEGER;
            previous_in_chain : LIST OF GENERIC := [];
            set_of_input_types : SET OF STRING := [];
            all_instances : SET OF GENERIC := [];
          END_LOCAL;
          all_instances := #{union};
          WHERE
            wr1: dependently_instantiated(all_instances, set_of_input_types, previous_in_chain);
          END_RULE;

          FUNCTION dependently_instantiated(
              set_of_input_instances : SET OF GENERIC:igen;
              set_of_input_types      : SET OF STRING;
              previous_in_chain       : LIST OF GENERIC:cgen): BOOLEAN;
          LOCAL
            number_of_input_instances : INTEGER;
            number_of_referring_instances : INTEGER;
            bag_of_referring_instances : BAG OF GENERIC:igen := [];
            dependently_instantiated_flag : BOOLEAN;
            previous_in_chain_plus : LIST OF GENERIC:cgen := [];
            result : BOOLEAN := true;
            set_of_types : SET OF STRING := [];
          END_LOCAL;
          IF EXISTS(set_of_input_instances) THEN
            number_of_input_instances := SIZEOF(set_of_input_instances);
            set_of_input_types := set_of_input_types + 'GENERIC';
            REPEAT i := 1 TO number_of_input_instances;
              bag_of_referring_instances := USEDIN(set_of_input_instances[i], '');
              IF EXISTS(bag_of_referring_instances) THEN
                number_of_referring_instances := SIZEOF(bag_of_referring_instances);
                dependently_instantiated_flag := false;
                REPEAT j := 1 TO number_of_referring_instances;
                  set_of_types := TYPEOF(bag_of_referring_instances[j]);
                  IF set_of_types <= set_of_input_types THEN
                    IF NOT (bag_of_referring_instances[j] IN previous_in_chain) THEN
                      previous_in_chain_plus := previous_in_chain +
                                                set_of_input_instances[i];
                      IF dependently_instantiated([bag_of_referring_instances[j]],
                                                  set_of_input_types,
                                                  previous_in_chain_plus) THEN
                        dependently_instantiated_flag := true;
                        ESCAPE;
                      ELSE
                        SKIP;
                      END_IF;
                    END_IF;
                  ELSE
                    dependently_instantiated_flag := true;
                    ESCAPE;
                  END_IF;
                END_REPEAT;
                IF NOT dependently_instantiated_flag THEN
                  RETURN(false);
                END_IF;
              ELSE
                RETURN(false);
              END_IF;
            END_REPEAT;
          ELSE
            RETURN(false);
          END_IF;
          RETURN(true);
          END_FUNCTION;
          END_SCHEMA;
        EXP
      end

      def parse_schema_snippet(src)
        Expressir::Express::Parser.from_exp(src)
      end

      # ---- G.2 stage 2 ----

      def build_longform
        artifact = build_artifact
        prune!(artifact) if @prune
        return artifact if @stage == :artifact

        if @extenders == :all
          resolve_extensible_enumerations!(artifact)
          resolve_extensible_selects!(artifact)
        end
        eliminate_subtype_constraints!(artifact)
        convert_abstract_entities!(artifact)
        convert_generic_entities!(artifact)
        convert_renamed_attributes!(artifact)
        rewrite_qualified_strings!(artifact)
        add_provenance_remark!(artifact)

        artifact
      end

      # G.1.10: optional embedded provenance remark — if any schema
      # name is kept in the longform, ALL contributing schemas are
      # recorded (`schema = <id> [schema_version_id = '<v>'];`, order
      # insignificant).
      def add_provenance_remark!(schema)
        names = closure.values.map(&:id).sort
        return if names.empty?

        remarks = ["Original 2003 schemas:"] + names.map do |id|
          contributing = closure.values.find { |s| s.id == id }
          version = contributing&.version&.id
          line = "schema = #{id};"
          line = "schema = #{id} schema_version_id = '#{version}';" if version
          line
        end
        schema.remark_items = [
          Model::Declarations::RemarkItem.new(id: "provenance", remarks: remarks),
          *Array(schema.remark_items),
        ]
      end

      # G.1.9 prune pass: the artifact keeps only what stays visible
      # and reachable. Runs before the stage-2 rewrites so they never
      # see declarations the longform would drop.
      def prune!(schema)
        visible_ids = visible_declaration_ids(schema)

        # rules whose parameter entities are not all visible
        schema.rules = schema.rules.reject do |rule|
          Array(rule.applies_to).any? do |ref|
            id = ref.is_a?(String) ? ref : ref.id
            id && !visible_ids.key?(id.safe_downcase)
          end
        end

        # select items pointing at declarations the artifact lacks
        schema.types.each do |type|
          next unless type.underlying_type.is_a?(Model::DataTypes::Select)

          items = Array(type.underlying_type.items)
          kept = items.select do |item|
            item.id.nil? || visible_ids.key?(item.id.safe_downcase)
          end
          # An emptied select disappears from the representation
          # (annex G.1.9 s1/s2/s3 example).
          type.underlying_type.items = kept unless kept.empty? && items.empty?
          if kept.empty? && !items.empty?
            type.underlying_type = nil
          end
        end
        schema.types = schema.types.reject { |t| t.underlying_type.nil? }

        # functions/procedures nothing calls, to fixpoint (a helper only
        # a dropped function called is itself unreachable)
        loop do
          called = called_ids(schema)
          drop = schema.functions.any? { |f| !called[f.id.safe_downcase] } ||
            schema.procedures.any? { |p| !called[p.id.safe_downcase] }
          break unless drop

          schema.functions = schema.functions.select { |f| called[f.id.safe_downcase] }
          schema.procedures = schema.procedures.select { |p| called[p.id.safe_downcase] }
        end

        prune_supertype_expressions!(schema, visible_ids)
      end

      def visible_declaration_ids(schema)
        all_decls(schema).each_with_object({}) do |decl, hash|
          hash[decl.id.safe_downcase] = true if decl.respond_to?(:id) && decl.id
        end
      end

      # Every identifier a call site or reference names, across the
      # artifact's surviving declarations: FunctionCall for functions,
      # ProcedureCall statements for procedures, and ANY SimpleReference
      # naming a schema function/procedure — a zero-argument function
      # used bare (`v < limit_value`) parses as a plain reference, not
      # a FunctionCall, and dropping it would leave the longform with a
      # dangling call. Over-retaining is safe: prune only decides what
      # may be dropped.
      def called_ids(schema)
        invocable = (schema.functions.to_a + schema.procedures.to_a)
          .map { |d| d.id.safe_downcase }
        called = {}
        each_node(schema) do |node|
          id = nil
          case node
          when Expressir::Model::Expressions::FunctionCall
            id = node.function.is_a?(String) ? node.function : node.function&.id
          when Expressir::Model::Statements::ProcedureCall
            id = node.procedure.is_a?(String) ? node.procedure : node.procedure&.id
          when Model::References::SimpleReference
            id = node.id
          end
          called[id.safe_downcase] = true if id && invocable.include?(id.safe_downcase)
        end
        called
      end

      # Annex C reductions over supertype expressions: references to
      # invisible entities leave ONEOF; ONEOF(a) => a; AND/OR sides
      # that become empty collapse; a vacuous expression deletes the
      # constraint.
      def prune_supertype_expressions!(schema, visible_ids)
        keep = []
        schema.subtype_constraints.each do |constraint|
          expr = constraint.supertype_expression
          if expr.nil?
            # total-over-only constraints carry no expression; stage 2
            # turns their TOTAL_OVER into a rule.
            keep << constraint
            next
          end
          reduced = reduce_supertype_expression(expr, visible_ids)
          # Annex C: a vacuous expression deletes the constraint.
          next if reduced.nil?

          constraint.supertype_expression = reduced
          keep << constraint
        end
        schema.subtype_constraints = keep
      end

      def reduce_supertype_expression(expr, visible_ids)
        case expr
        when Model::SupertypeExpressions::OneofSupertypeExpression
          reduced = expr.operands.filter_map do |operand|
            reduce_supertype_expression(operand, visible_ids)
          end
          return nil if reduced.empty?

          reduced.one? ? reduced.first : reset_oneof(expr, reduced)
        when Model::SupertypeExpressions::BinarySupertypeExpression
          left = reduce_supertype_expression(expr.operand1, visible_ids)
          right = reduce_supertype_expression(expr.operand2, visible_ids)
          if left.nil?
            return right
          end
          if right.nil?
            return left
          end

          rebuild_binary(expr, left, right)
        when Model::References::SimpleReference
          id = expr.id
          return nil if id && !visible_ids.key?(id.safe_downcase)

          expr
        else
          expr
        end
      end

      def reset_oneof(expr, refs)
        copy = deep_copy(expr)
        copy.operands = refs
        copy
      end

      def rebuild_binary(expr, left, right)
        copy = deep_copy(expr)
        copy.operand1 = left
        copy.operand2 = right
        copy
      end

      def resolve_extensible_enumerations!(schema)
        schema.types.select do |t|
          t.underlying_type.is_a?(Model::DataTypes::Enumeration) && t.underlying_type.extensible
        end.each do |base|
          enum = base.underlying_type
          extensions = schema.types.select do |t|
            t.underlying_type.is_a?(Model::DataTypes::Enumeration) &&
              !t.underlying_type.extensible &&
              t.underlying_type.based_on&.id&.safe_downcase == base.id.safe_downcase
          end
          merged = enum.items.map(&:id) +
            extensions.flat_map { |x| x.underlying_type.items.map(&:id) }
          enum.items = merged.uniq.map { |id| Model::DataTypes::EnumerationItem.new(id: id) }
          enum.extensible = false
          enum.based_on = nil

          extensions.each do |ext|
            ext_items = ext.underlying_type.items.map(&:id)
            exclusions = merged - ext_items
            ext.underlying_type = Model::DataTypes::Enumeration.new(
              items: enum.items,
            )
            ext.where_rules = exclusions.each_with_index.map do |item, i|
              Model::Declarations::WhereRule.new(
                id: "wr#{i + 1}",
                expression: parse_expression("SELF <> #{item};"),
              )
            end
          end
        end
      end

      # G.2.2/G.2.4: every extensible/extending select becomes a
      # non-extensible select whose items are the full domain in
      # longform scope. Chains fold in dependency order (a node whose
      # own BASED_ON is still pending is deferred), so an extending
      # type that is itself extensible resolves against its base's
      # folded domain.
      # G.2.2/G.2.4: every extensible/extending select becomes a
      # non-extensible select whose items are the full domain in
      # longform scope. Chains fold in dependency order (a node whose
      # own BASED_ON is still pending is deferred), so an extending
      # type that is itself extensible resolves against its base's
      # folded domain.
      def resolve_extensible_selects!(schema)
        select_types = schema.types.select do |ty|
          ty.underlying_type.is_a?(Model::DataTypes::Select)
        end
        select_types.select { |ty| sel_pending?(ty) }.each do |base|
          fold_select_node(schema, select_types, base)
        end
      end

      def sel_pending?(select_type)
        sel = select_type.underlying_type
        sel.extensible || sel.based_on
      end

      def fold_select_node(schema, select_types, base_type)
        sel = base_type.underlying_type
        return unless sel_pending?(base_type)

        # all-extenders for GENERIC_ENTITY selects (WG12 requirement,
        # #32): the extenders are the entity types themselves — fold in
        # every entity the artifact carries, so the longform select is
        # complete against the closure. Flags stay as declared: the
        # extensible/generic-entity markers are part of the shortform's
        # semantics and are not expressir's to drop.
        if sel.generic_entity && !sel.based_on
          sel.items = schema.entities.map do |e|
            Model::References::SimpleReference.new(id: e.id)
          end
          return
        end

        own_items = Array(sel.items)
        inherited = []
        if sel.based_on
          base_ty = select_types.find do |ty|
            ty.id&.safe_downcase == sel.based_on&.id&.safe_downcase
          end
          fold_select_node(schema, select_types, base_ty) if base_ty && sel_pending?(base_ty)
          inherited = base_ty ? Array(base_ty.underlying_type.items) : []
        end

        extenders = select_types.select do |ty|
          !ty.equal?(base_type) &&
            ty.underlying_type.based_on&.id&.safe_downcase == base_type.id&.safe_downcase
        end

        merged = inherited + own_items +
          extenders.flat_map { |ty| Array(ty.underlying_type.items) }
        seen = {}
        uniq = merged.select do |item|
          key = item.id.safe_downcase
          next false if key.empty? || seen.key?(key)

          seen[key] = true
        end
        sel.items = uniq
        sel.extensible = false
        sel.based_on = nil

        extenders.each do |ty|
          ext_sel = ty.underlying_type
          keep = Array(ext_sel.items).map { |i| i.id.upcase }
          base_ref = "#{@longform_name.upcase}.#{base_type.id.upcase}"
          ty.underlying_type = Model::DataTypes::Select.new(
            items: uniq.map { |i| Model::References::SimpleReference.new(id: i.id) },
          )
          ext_sel_items = ty.underlying_type.items
          exclusions = uniq.reject { |i| keep.include?(i.id.upcase) }
          ty.where_rules = exclusions.each_with_index.map do |item, i|
            Model::Declarations::WhereRule.new(
              id: "wr#{i + 1}",
              expression: parse_expression(
                "NOT ('#{base_ref}.#{item.id.upcase}' IN TYPEOF(SELF));",
              ),
            )
          end
          ext_sel_items
        end
      end

      def eliminate_subtype_constraints!(schema)
        schema.subtype_constraints.each do |sc|
          entity = schema.entities.find do |e|
            e.id.safe_downcase == sc.applies_to&.id&.safe_downcase
          end
          next unless entity

          if sc.supertype_expression
            expr = sc.supertype_expression
            entity.supertype_expression =
              entity.supertype_expression ? combine_andor(entity.supertype_expression, expr) : expr
          end
          entity.abstract = true if sc.abstract
          next if Array(sc.total_over).empty?

          rule_name = "total_over_#{sc.id}"
          targets = Array(sc.total_over).map { |r| r.id.upcase }
          supertype = sc.applies_to&.id
          rule = parse_schema_snippet(<<~EXP).schemas.first.rules.first
            SCHEMA __to__;
            RULE #{rule_name} FOR (#{supertype.upcase});
            WHERE
              wr1: SIZEOF(QUERY(#{supertype.downcase}_i <* #{supertype} |
                SIZEOF(['#{@longform_name.upcase}.#{targets.first}'] * TYPEOF(#{supertype.downcase}_i)) = 0)) = 0;
            END_RULE;
            END_SCHEMA;
          EXP
          rule.id = rule_name
          schema.rules = Array(schema.rules) + [rule]
        end
        schema.subtype_constraints = []
      end

      def combine_andor(left, right)
        Model::SupertypeExpressions::BinarySupertypeExpression.new(
          operator: Model::SupertypeExpressions::BinarySupertypeExpression::ANDOR,
          operand1: left, operand2: right
        )
      rescue StandardError
        left
      end

      def convert_abstract_entities!(schema)
        schema.entities.each do |entity|
          next unless entity.abstract

          entity.abstract = true # formatter renders ABSTRACT SUPERTYPE when supertype present
        end
      end

      def convert_generic_entities!(schema)
        each_node(schema) do |node|
          replace_in_parent(node, Model::DataTypes::Generic.new) if node.is_a?(Model::DataTypes::GenericEntity)
        end
      end

      def replace_in_parent(node, replacement)
        parent = node.parent
        return unless parent

        parent.class.attributes.each_key do |attr|
          next if Model::ModelElement::SKIP_ATTRIBUTES.include?(attr)

          value = parent.public_send(attr)
          case value
          when Array
            value.each_with_index do |item, index|
              parent.public_send(attr)[index] = replacement if item.equal?(node)
            end
          else
            parent.public_send(:"#{attr}=", replacement) if value.equal?(node) && parent.respond_to?(:"#{attr}=")
          end
        end
      end

      def convert_renamed_attributes!(schema)
        schema.entities.each do |entity|
          entity.attributes.each_with_index do |attr, i|
            next unless attr.supertype_attribute

            old_name, supertype = supertype_target(attr.supertype_attribute)
            entity.attributes[i] = Model::Declarations::DerivedAttribute.new(
              id: attr.id || old_name,
              type: attr.type,
              expression: parse_expression("SELF\\#{supertype}.#{old_name}"),
            )
          end
        end
      end

      # `SELF\ENTITY.attr` parses as AttributeReference(ref: GroupReference
      # (SELF, entity), attribute: attr); a bare qualified attribute has
      # only the attribute name.
      def supertype_target(ref)
        return [ref.id, nil] unless ref.is_a?(Model::References::AttributeReference)

        group = ref.ref
        [ref.attribute&.id,
         group.is_a?(Model::References::GroupReference) ? group.entity&.id : nil]
      end

      # G.NM.2: string literals carrying schema-qualified names (e.g.
      # TYPEOF arguments 'SCHEMA.TYPE') move to the longform name.
      # Structurally these appear as DataTypes::String; path references
      # in expressions are already renamed by the copy pass.
      def rewrite_qualified_strings!(schema)
        prefixes = closure.keys.map(&:upcase)
        each_node(schema) do |node|
          next unless node.is_a?(Model::Literals::String) && node.value

          node.value = node.value.sub(/\A(#{prefixes.join('|')})\./i,
                                      "#{@longform_name.upcase}.")
        end
      end

      # Attribute-driven structural traversal over the whole subtree.
      def each_node(root, &)
        stack = [root]
        until stack.empty?
          node = stack.pop
          yield node
          next unless node.is_a?(Model::ModelElement)

          node.class.attributes.each_key do |attr|
            next if Model::ModelElement::SKIP_ATTRIBUTES.include?(attr)

            value = node.public_send(attr)
            case value
            when Array then value.each { |item| stack << item if item.is_a?(Model::ModelElement) }
            when Model::ModelElement then stack << value
            end
          end
        end
      end

      def parse_expression(src)
        snippet = "SCHEMA __x__; ENTITY __e__; WHERE w1 : #{src.chomp(';')}; END_ENTITY; END_SCHEMA;"
        parsed = parse_schema_snippet(snippet)
        parsed.schemas.first.entities.first.where_rules.first.expression
      end
    end
  end
end
