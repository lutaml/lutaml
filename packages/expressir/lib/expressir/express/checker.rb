# frozen_string_literal: true

module Expressir
  module Express
    # Semantic checks modeled on eeng kernel/check.lisp + check-notes.lisp
    # (expressir parity-ee stage 07). Each note preserves the eeng note id
    # so oracle differentials stay cross-referenceable.
    #
    # Coverage is a deliberate subset of eeng's check-p11 catalog:
    #   check-schema-interface-redundant
    #   check-schema-iface-resource-duplicate
    #   check-subtype-ref
    #   check-subtype-cycle
    #   check-duplicate-declaration
    #   check-where-name-pattern   (entity, type, rule)
    #   check-unique-name-pattern
    #   check-unresolved-ref   (aggregate of eeng type/entity unparsed notes)
    #   check-select-extended-type
    #   check-enumeration-extended-type
    #   check-inverse-entity/-attrib-ref/-inverse/-derive (tranche 3)
    #   qualified-attrib-group-not-found/-not-ancestor,
    #   qualified-attrib-attr-not-found (tranche 3)
    #
    # Severity: :error stops a clean SHTOLO run; :warning is advisory.
    class Checker
      Note = Struct.new(:id, :severity, :schema, :message, :node, keyword_init: true)

      WHERE_LABEL = /\AWR\d+\z/i
      UNIQUE_LABEL = /\AUR\d+\z/i
      DECL_COLLECTIONS = %i[types entities functions procedures constants rules
                            subtype_constraints].freeze

      attr_reader :notes

      def initialize(repository, dialect: nil)
        @repository = repository
        @dialect = dialect.nil? ? nil : Dialect.normalize(dialect)
        @notes = []
        # Case-folded index to LISTS of schemas: EXPRESS schema ids are
        # case-insensitive, and two schemas differing only in case are
        # distinct declarations that must not silently overwrite each other.
        @by_name = {}
        repository.schemas.compact.each do |schema|
          next unless schema.id

          (@by_name[schema.id.safe_downcase] ||= []) << schema
        end
      end

      def check
        @notes = []
        @repository.schemas.compact.each { |schema| check_schema(schema) }
        self
      end

      def errors
        notes.select { |n| n.severity == :error }
      end

      def warnings
        notes.select { |n| n.severity == :warning }
      end

      def valid?
        errors.empty?
      end

      def report(io = $stdout)
        notes.each do |n|
          io.puts "[#{n.severity}] #{n.id}: #{n.message}"
        end
        io.puts "#{errors.size} error(s), #{warnings.size} warning(s)"
        io
      end

      BUILTINS = %w[
        integer real number string binary boolean logical generic
        generic_entity aggregate array bag list set
        true false unknown self const_e pi
        abs acos asin atan cos exp format hibound hiindex length
        log log2 log10 lobound loindex nvl odd rolesof sin sizeof
        sqrt tan typeof usedin value value_in value_unique exists
        blength insert remove
      ].freeze

      USE_ITEM_KINDS = [Model::Declarations::Entity, Model::Declarations::Type].freeze
      REFERENCE_ITEM_KINDS = [
        Model::Declarations::Constant, Model::Declarations::Entity,
        Model::Declarations::Function, Model::Declarations::Procedure,
        Model::Declarations::Type
      ].freeze

      NUMERIC_TYPES = %i[integer real number].freeze
      LOGICAL_TYPES = %i[logical boolean].freeze
      ORDERING_FAMILIES = {
        numeric: NUMERIC_TYPES,
        logical: LOGICAL_TYPES,
        string: %i[string],
        binary: %i[binary],
        enum: %i[enum],
      }.freeze

      TYPE_CLASS_SYMBOLS = {
        Model::DataTypes::Integer => :integer,
        Model::DataTypes::Real => :real,
        Model::DataTypes::Number => :number,
        Model::DataTypes::String => :string,
        Model::DataTypes::Binary => :binary,
        Model::DataTypes::Boolean => :boolean,
        Model::DataTypes::Logical => :logical,
        Model::DataTypes::List => :aggregate,
        Model::DataTypes::Set => :aggregate,
        Model::DataTypes::Bag => :aggregate,
        Model::DataTypes::Array => :aggregate,
      }.freeze

      private

      def note!(id, severity, schema, message, node = nil)
        @notes << Note.new(id: id, severity: severity, schema: schema&.id,
                           message: message, node: node)
      end

      def check_schema(schema)
        check_duplicates(schema)
        check_interfaces(schema)
        check_type_resolutions(schema)
        check_self_schema_reference(schema)
        schema.entities.each { |e| check_entity(schema, e) }
        schema.types.each do |t|
          check_type(schema, t)
          check_select_items(schema, t)
          check_where_rules(schema, t, t.where_rules)
        end
        schema.rules.each { |r| check_where_rules(schema, r, r.where_rules) }
        check_subtype_constraints(schema)
        schema.entities.each do |entity|
          check_aggregate_bounds(schema, entity)
          check_attrib_name_fun(schema, entity)
          check_attribute_redeclarations(schema, entity)
        end
        check_string_references(schema)
        check_unresolved_refs(schema)
        check_expression_types(schema)
        check_statement_types(schema)
        check_rule_structure(schema)
        check_dialect(schema) if @dialect
      end

      # ---- TODO.sota/06: edition awareness ----
      # The grammar accepts both editions; the selected dialect decides
      # which declarations are out of edition. The audited change list
      # is spec/fixtures/dialects/iso-10303-11-2004-changes.yaml.
      def check_dialect(schema)
        modern = dialect_2004_constructs(schema)
        deprecated = Array(schema.entities).select do |entity|
          deprecated_inline_supertype?(entity)
        end

        if @dialect == Dialect::EDITION_1994
          modern.each do |node, message|
            note!(:check_dialect_2004_only, :error, schema,
                  "dialect 10303-11:1994: #{message}", node)
          end
        else
          deprecated.each do |entity|
            note!(:check_dialect_deprecated, :warning, schema,
                  "dialect 10303-11:2004: #{entity.id}: inline subtype " \
                  "constraint syntax is deprecated; use SUBTYPE_CONSTRAINT " \
                  "(Annex K)", entity)
          end
        end

        return unless modern.any? && deprecated.any?

        note!(:check_dialect_mixed, :warning, schema,
              "dialect: schema mixes 2004-only declarations with " \
              "edition-1 inline subtype constraint syntax", deprecated.first)
      end

      def dialect_2004_constructs(schema)
        constructs = []
        Array(schema.types).each do |type|
          underlying = type.underlying_type
          next unless underlying

          if underlying.respond_to?(:extensible) && underlying.extensible
            constructs << [type,
                           "#{type.id}: EXTENSIBLE is not part of " \
                           "ISO 10303-11:1994 (2004 edition, 8.4.1/8.4.2)"]
          end
          if underlying.respond_to?(:based_on) && underlying.based_on
            constructs << [type,
                           "#{type.id}: BASED_ON is not part of " \
                           "ISO 10303-11:1994 (2004 edition, 8.4.1/8.4.2)"]
          end
          if underlying.respond_to?(:generic_entity) && underlying.generic_entity
            constructs << [type,
                           "#{type.id}: GENERIC_ENTITY is not part of " \
                           "ISO 10303-11:1994 (2004 edition, 8.4.2)"]
          end
        end
        Array(schema.subtype_constraints).each do |constraint|
          constructs << [constraint,
                         "#{constraint.id}: SUBTYPE_CONSTRAINT is not part " \
                         "of ISO 10303-11:1994 (2004 edition, 9; Annex G)"]
        end
        constructs
      end

      def deprecated_inline_supertype?(entity)
        expression = entity.supertype_expression
        expression.is_a?(Model::SupertypeExpressions::OneofSupertypeExpression) ||
          expression.is_a?(Model::SupertypeExpressions::BinarySupertypeExpression)
      end

      # ---- TODO.sota/01 tier 2: operator domain typing ----
      # ISO 10303-11:2004 ch.12. eengine's expression checks traverse
      # structurally only (kernel/check.lisp), so these notes carry the
      # new :check_expr_operand_domain id with the clause in the
      # message. A violation is flagged only when BOTH operand types
      # are statically known.

      def check_expression_types(schema)
        check_initializer_types(schema)
        expression_scopes(schema).each do |scope|
          @current_expression_env = expression_env(schema, scope)
          each_node(scope) do |node|
            case node
            when Model::Expressions::BinaryExpression
              check_binary_expression_types(schema, node)
            when Model::Expressions::UnaryExpression
              check_unary_expression_types(schema, node)
            when Model::Expressions::Interval
              check_interval_types(schema, node)
            when Model::References::IndexReference
              check_index_reference_types(schema, node)
            end
          end
        end
        @current_expression_env = nil
      end

      def expression_scopes(schema)
        Array(schema.constants) + Array(schema.types) +
          Array(schema.entities) + Array(schema.functions) +
          Array(schema.procedures) + Array(schema.rules)
      end

      # name → declared type node, for identifiers visible to the
      # scope's expressions: the schema's constants, plus the scope's
      # own parameters/variables/attributes.
      def expression_env(schema, scope)
        env = {}
        Array(schema.constants).each do |constant|
          env[constant.id&.safe_downcase] = constant.type if constant.id
        end
        case scope
        when Model::Declarations::Entity
          Array(scope.attributes).each do |attr|
            env[attr.id&.safe_downcase] = attr.type if attr.id
          end
        when Model::Declarations::Function, Model::Declarations::Procedure
          Array(scope.parameters).each do |param|
            env[param.id&.safe_downcase] = param.type if param.id
          end
          Array(scope.variables).each do |variable|
            env[variable.id&.safe_downcase] = variable.type if variable.id
          end
        when Model::Declarations::Rule
          Array(scope.variables).each do |variable|
            env[variable.id&.safe_downcase] = variable.type if variable.id
          end
        end
        env
      end

      def check_binary_expression_types(schema, node)
        left = static_type(schema, node.operand1)
        right = static_type(schema, node.operand2)
        return if undecidable?(left, right)

        domain = binary_domain_violation(node.operator, left, right)
        return unless domain

        note!(:check_expr_operand_domain, :error, schema,
              "operator '#{binary_operator_spelling(node.operator)}': " \
              "#{domain} (#{left} vs #{right})", node)
      end

      def undecidable?(*types)
        types.any? { |t| t.nil? || t == :unknown || t == :generic }
      end

      # nil = ok; String = the violation message body. Clauses per the
      # TODO.sota/01 clause map.
      def binary_domain_violation(operator, left, right)
        case operator
        when "ADDITION"
          return nil if numeric_pair?(left, right) ||
            same_pair?(left, right, :string) ||
            same_pair?(left, right, :binary) ||
            left == :aggregate || right == :aggregate

          # 12.6 table 17: union admits an element singleton on either
          # side of an aggregate; element↔base-type compatibility is a
          # later tier.
          "addition requires numeric, string, binary or aggregate " \
            "operands (12.1, 12.3.2, 12.5.2, 12.6)"
        when "SUBTRACTION"
          return nil if numeric_pair?(left, right) ||
            (left == :aggregate && right != :unknown) ||
            same_pair?(left, right, :aggregate)

          # 12.6 table 18: the difference's right operand may be an
          # element singleton; the left must be an aggregate.
          "difference requires an aggregate left operand (12.1, 12.6)"
        when "MULTIPLICATION"
          return nil if numeric_pair?(left, right) ||
            same_pair?(left, right, :aggregate)

          "intersection requires aggregate operands (12.1, 12.6)"
        when "REAL_DIVISION", "EXPONENTIATION", "INTEGER_DIVISION", "MODULO"
          "operator requires numeric operands (12.1)" unless numeric_pair?(left, right)
        when "AND", "OR", "XOR"
          "logical operator requires logical operands (12.4)" unless
            LOGICAL_TYPES.include?(left) && LOGICAL_TYPES.include?(right)
        when "EQUAL", "NOT_EQUAL"
          "value comparison requires comparable operands (12.2.1)" unless
            comparable_equality?(left, right)
        when "LESS_THAN", "LESS_THAN_OR_EQUAL", "GREATER_THAN",
             "GREATER_THAN_OR_EQUAL"
          if left == :aggregate || right == :aggregate
            unless left == :aggregate && right == :aggregate
              return "subset/superset requires aggregate operands (12.6)"
            end

            return nil
          end

          "ordering comparison requires same-family operands (12.2.1)" unless
            same_ordering_family?(left, right)
        when "INSTANCE_EQUAL", "INSTANCE_NOT_EQUAL"
          unless %i[entity aggregate select].include?(left) &&
              %i[entity aggregate select].include?(right)
            "instance comparison requires entity or aggregate " \
              "operands (12.2.2)"
          end
        when "IN"
          "membership requires an aggregate right operand (12.2.3)" unless
            right == :aggregate
        when "LIKE"
          "like requires string operands (12.2.5)" unless
            left == :string && right == :string
        when "COMBINE"
          unless left == :entity && right == :entity
            "complex entity construction requires entity operands " \
              "(12, precedence table note)"
          end
        end
      end

      def numeric_pair?(left, right)
        NUMERIC_TYPES.include?(left) && NUMERIC_TYPES.include?(right)
      end

      def same_pair?(left, right, kind)
        left == kind && right == kind
      end

      # 12.2.1: both operands of the same comparison family, with the
      # numeric family spanning integer/real/number; aggregate/entity/
      # select operands compare for (in)equality only.
      def comparable_equality?(left, right)
        return true if %i[aggregate entity select].include?(left) &&
          %i[aggregate entity select].include?(right)

        same_ordering_family?(left, right)
      end

      def same_ordering_family?(left, right)
        ORDERING_FAMILIES.values.any? do |family|
          family.include?(left) && family.include?(right)
        end
      end

      def binary_operator_spelling(symbol)
        {
          "ADDITION" => "+", "SUBTRACTION" => "-", "REAL_DIVISION" => "/",
          "INTEGER_DIVISION" => "div", "MODULO" => "mod",
          "INSTANCE_EQUAL" => ":=:", "INSTANCE_NOT_EQUAL" => ":<>:"
        }.fetch(symbol, symbol.downcase)
      end

      def check_unary_expression_types(schema, node)
        t = static_type(schema, node.operand)
        return if undecidable?(t)

        violation =
          if node.operator == "NOT"
            "not requires a logical operand (12.4)" unless
              LOGICAL_TYPES.include?(t)
          else
            unless NUMERIC_TYPES.include?(t)
              "unary '#{node.operator.downcase}' requires a numeric " \
                "operand (12.1)"
            end
          end
        return unless violation

        note!(:check_expr_operand_domain, :error, schema, violation, node)
      end

      def check_interval_types(schema, node)
        types = [node.low, node.item, node.high].map do |part|
          static_type(schema, part)
        end
        return if types.any? { |t| undecidable?(t) }
        return if types.all? { |t| same_ordering_family?(types.first, t) } ||
          numeric_family?(*types)

        note!(:check_expr_operand_domain, :error, schema,
              "interval bounds must be mutually comparable (12.2.4) " \
              "(#{types.join(' vs ')})", node)
      end

      def numeric_family?(*types)
        types.all? { |t| NUMERIC_TYPES.include?(t) }
      end

      # Static type of an expression node: a symbol from the lattice
      # in TODO.sota/01 (:unknown when not statically decidable).
      def static_type(schema, node, depth = 0)
        return :unknown if node.nil? || depth > 8
        return TYPE_CLASS_SYMBOLS[node.class] if TYPE_CLASS_SYMBOLS.key?(node.class)

        case node
        when Model::Literals::Integer then :integer
        when Model::Literals::Real then :real
        when Model::Literals::String then :string
        when Model::Literals::Binary then :binary
        when Model::Literals::Logical then :logical
        when Model::Expressions::AggregateInitializer,
             Model::Expressions::QueryExpression then :aggregate
        when Model::Expressions::EntityConstructor,
             Model::References::GroupReference then :entity
        when Model::Expressions::BinaryExpression
          binary_result_type(schema, node, depth)
        when Model::Expressions::FunctionCall
          function = schema_function(schema, node)
          return :unknown unless function

          static_type(schema, function.return_type, depth + 1)
        when Model::DataTypes::Enumeration then :enum
        when Model::DataTypes::Select then :select
        when Model::DataTypes::Generic, Model::DataTypes::GenericEntity
          :generic
        when Model::References::SimpleReference
          reference_type(schema, node, depth)
        when Model::References::AttributeReference
          attribute_reference_type(schema, node, depth)
        when Model::References::IndexReference
          index_element_type(schema, node, depth)
        else :unknown
        end
      end

      def binary_result_type(schema, node, depth)
        case node.operator
        when "EQUAL", "NOT_EQUAL", "LESS_THAN", "LESS_THAN_OR_EQUAL",
             "GREATER_THAN", "GREATER_THAN_OR_EQUAL", "IN", "LIKE",
             "INSTANCE_EQUAL", "INSTANCE_NOT_EQUAL", "AND", "OR", "XOR"
          :logical
        when "ADDITION"
          left = static_type(schema, node.operand1, depth + 1)
          NUMERIC_TYPES.include?(left) ? left : :unknown
        when "REAL_DIVISION" then :real
        when "INTEGER_DIVISION", "MODULO" then :integer
        when "EXPONENTIATION"
          both = [node.operand1, node.operand2].map do |operand|
            static_type(schema, operand, depth + 1)
          end
          both.all?(:integer) ? :integer : :unknown
        else :unknown
        end
      end

      def builtin_symbol(name)
        {
          "integer" => :integer, "real" => :real, "number" => :number,
          "string" => :string, "binary" => :binary, "boolean" => :boolean,
          "logical" => :logical
        }.fetch(name, :unknown)
      end

      def schema_function(schema, node)
        callee = node.function
        return nil unless callee.is_a?(Model::References::SimpleReference)

        Array(schema.functions).find do |function|
          function.id&.safe_downcase == callee.id&.safe_downcase
        end
      end

      def reference_type(schema, node, depth)
        key = node.id&.safe_downcase
        return :unknown unless key

        # builtin type names may arrive as unresolved references
        # depending on parse layout
        return builtin_symbol(key) if builtin?(node.id)

        if (bound = @current_expression_env&.[](key))
          return static_type(schema, bound, depth + 1)
        end

        declaration = find_type(schema, node.id.to_s)
        return static_type(schema, declaration.underlying_type, depth + 1) if declaration

        find_entity(schema, node.id) ? :entity : :unknown
      end

      # `color.red` parses as an AttributeReference over a reference to
      # the enumeration TYPE (base infers :enum). An entity-typed base
      # resolves through the entity's own attributes.
      def attribute_reference_type(schema, node, depth)
        base_node = node.ref
        base = static_type(schema, base_node, depth + 1)
        return :enum if base == :enum

        entity = entity_for_reference(schema, base_node)
        return :unknown unless entity

        attr = Array(entity.attributes).find do |candidate|
          candidate.id&.safe_downcase == node.attribute&.id&.safe_downcase
        end
        return :unknown unless attr

        static_type(schema, attr.type, depth + 1)
      end

      def entity_for_reference(schema, node)
        return nil unless node.is_a?(Model::References::SimpleReference)

        find_entity(schema, node.id.to_s)
      end

      # ---- tier 3: aggregates through indexing ----

      # 12.6.1 / 12.3.1 / 12.5.1: indexing yields the aggregate's base
      # element; string indexing yields a string; binary indexing a
      # binary.
      def index_element_type(schema, node, depth)
        element = index_element_type_node(schema, node.ref, depth + 1)
        return :unknown if element.nil?

        symbol = static_type(schema, element, depth + 1)
        return symbol unless symbol == :unknown

        case element
        when Model::DataTypes::String then :string
        when Model::DataTypes::Binary then :binary
        else :unknown
        end
      end

      def index_element_type_node(schema, node, depth)
        return nil if node.nil? || depth > 8

        type_node = declared_type_node(schema, node, depth)
        case type_node
        when Model::DataTypes::List, Model::DataTypes::Set,
             Model::DataTypes::Bag, Model::DataTypes::Array
          type_node.base_type
        when Model::DataTypes::String, Model::DataTypes::Binary
          type_node
        when Model::DataTypes::Select
          nil
        end
      end

      # The declared type NODE an expression position names (as opposed
      # to the static_type symbol): scope environment, schema types and
      # entities, function returns.
      def declared_type_node(schema, node, depth)
        case node
        when Model::References::SimpleReference
          key = node.id&.safe_downcase
          return nil unless key

          @current_expression_env&.[](key) ||
            find_type(schema, node.id.to_s)&.underlying_type ||
            (find_entity(schema, node.id) && Model::DataTypes::GenericEntity.new)
        when Model::References::IndexReference
          index_element_type_node(schema, node.ref, depth + 1)
        when Model::Expressions::FunctionCall
          function = schema_function(schema, node)
          function&.return_type
        end
      end

      # 12.6.1/12.3.1/12.5.1: the indexed value shall be an aggregate,
      # string or binary; 12.6.1/12.3.1/12.5.1 + 12.1: index positions
      # shall be numeric.
      def check_index_reference_types(schema, node)
        base = static_type(schema, node.ref)
        unless undecidable?(base) || base == :aggregate ||
            base == :string || base == :binary || base == :select
          note!(:check_expr_operand_domain, :error, schema,
                "indexing requires an aggregate, string or binary " \
                "operand (12.6.1, 12.3.1, 12.5.1) (#{base})", node)
        end

        [node.index1, node.index2].compact.each do |position|
          position_type = static_type(schema, position)
          next if undecidable?(position_type)
          next if NUMERIC_TYPES.include?(position_type)

          note!(:check_expr_operand_domain, :error, schema,
                "index position shall be numeric (12.6.1) " \
                "(#{position_type})", position)
        end
      end

      # ---- tier 4: initializer compatibility (12.11) ----

      # `x : T := expr` in CONSTANT, DERIVE and LOCAL: the initializer
      # shall be compatible with the declared type (same type or a
      # specialization, 12.11); numerics widen integer→real→number.
      def check_initializer_types(schema)
        initializers(schema).each do |owner, declaration|
          @current_expression_env = if owner
                                      expression_env(schema, owner)
                                    else
                                      expression_env(schema, schema)
                                    end
          declared = static_type(schema, declaration.type)
          expression = declaration.expression
          next if expression.nil? || undecidable?(declared)

          expressed = static_type(schema, expression)
          next if undecidable?(expressed)
          next if initializer_compatible?(schema, declaration.type,
                                          declared, expression, expressed)

          note!(:check_expr_initializer_type, :error, schema,
                "initializer #{expressed} is not compatible with the " \
                "declared #{declared} (12.11)", declaration)
        end
        @current_expression_env = nil
      end

      def initializers(schema)
        pairs = []
        Array(schema.constants).each do |constant|
          pairs << [nil, constant] if constant.expression
        end
        schema.entities.each do |entity|
          Array(entity.attributes).each do |attr|
            next unless attr.is_a?(Model::Declarations::Attribute) &&
              !attr.is_a?(Model::Declarations::InverseAttribute) &&
              attr.expression

            pairs << [entity, attr]
          end
        end
        schema.functions.each do |function|
          Array(function.variables).each do |variable|
            pairs << [function, variable] if variable.expression
          end
        end
        pairs
      end

      def initializer_compatible?(schema, declared_node, declared, expression, expressed)
        # enum and entity symbols are families, not identities — their
        # compatibility is decided by declaration comparison below.
        return true if declared == expressed &&
          !%i[enum entity].include?(declared)
        return true if declared == :number && NUMERIC_TYPES.include?(expressed)
        return true if declared == :real && expressed == :integer
        return true if LOGICAL_TYPES.include?(declared) &&
          LOGICAL_TYPES.include?(expressed)
        return true if declared == :select
        return true if expressed == :select
        return true if declared == :aggregate && expressed == :aggregate

        # enumerations: same declared TYPE (expression enum members are
        # AttributeReferences over the enumeration type)
        return same_enum_declaration?(schema, declared_node, expression) if
          declared == :enum && expressed == :enum

        # entities: same entity or a specialization (12.11)
        return entities_compatible?(schema, declared_node, expression) if
          declared == :entity && expressed == :entity

        false
      end

      # Resolve a type reference chain to its Type or Entity
      # declaration: schema types and entities first, then the scope
      # environment, then attribute/index member resolution.
      def resolved_declaration(schema, node, depth = 0)
        return nil if node.nil? || depth > 6

        case node
        when Model::Declarations::Type, Model::Declarations::Entity
          node
        when Model::References::SimpleReference
          key = node.id&.safe_downcase
          return nil unless key

          bound = @current_expression_env&.[](key)
          resolved_declaration(schema,
                               bound || find_type(schema, node.id.to_s) ||
                               find_entity(schema, node.id), depth + 1)
        when Model::References::AttributeReference
          owner = resolved_declaration(schema, node.ref, depth + 1)
          # an enumeration member (`color.red`): the declaration is the
          # enumeration TYPE itself
          return owner if owner.is_a?(Model::Declarations::Type) &&
            owner.underlying_type.is_a?(Model::DataTypes::Enumeration)

          return nil unless owner.is_a?(Model::Declarations::Entity)

          attr = Array(owner.attributes).find do |candidate|
            candidate.id&.safe_downcase == node.attribute&.id&.safe_downcase
          end
          resolved_declaration(schema, attr&.type, depth + 1)
        when Model::References::IndexReference
          element = index_element_type_node(schema, node.ref, depth + 1)
          resolved_declaration(schema, element, depth + 1)
        when Model::References::GroupReference
          resolved_declaration(schema, node.entity, depth + 1)
        when Model::Expressions::FunctionCall
          function = schema_function(schema, node)
          resolved_declaration(schema, function&.return_type, depth + 1)
        end
      end

      def same_enum_declaration?(schema, declared_node, expression)
        slot_enum = resolved_declaration(schema, declared_node)
        expr_enum = resolved_declaration(schema, expression)
        return false unless slot_enum.is_a?(Model::Declarations::Type) &&
          expr_enum.is_a?(Model::Declarations::Type)

        slot_enum.underlying_type.is_a?(Model::DataTypes::Enumeration) &&
          expr_enum.underlying_type.is_a?(Model::DataTypes::Enumeration) &&
          slot_enum.id&.safe_downcase == expr_enum.id&.safe_downcase
      end

      def entities_compatible?(schema, declared_node, expression)
        slot_entity = resolved_declaration(schema, declared_node)
        expr_entity = resolved_declaration(schema, expression)
        return false unless slot_entity.is_a?(Model::Declarations::Entity) &&
          expr_entity.is_a?(Model::Declarations::Entity)

        slot_entity.id&.safe_downcase == expr_entity.id&.safe_downcase ||
          expr_entity.supertype_closure
            .map { |e| e.id&.safe_downcase }
            .include?(slot_entity.id&.safe_downcase)
      end

      # Self-qualified literals naming the CURRENT schema (#125): local
      # items must not be prefixed, foreign items must name their true
      # defining schema (ISO 10303-11 scope rules).
      def check_self_schema_reference(schema)
        SelfSchemaReference.matches(schema).each do |match|
          case match.status
          when :local
            note!(:check_self_schema_reference, :warning, schema,
                  "self-qualified '#{schema.id}.#{match.item}' — " \
                  "'#{match.item}' is local; drop the prefix", match.literal)
          when :foreign
            note!(:check_self_schema_reference, :warning, schema,
                  "self-qualified '#{schema.id}.#{match.item}' — item is " \
                  "defined in '#{match.source_schema.id}'", match.literal)
          end
        end
      end

      # Two declarations in one schema sharing a (case-insensitive) name is
      # invalid EXPRESS — the second can never be referenced.
      def check_duplicates(schema)
        seen = {}
        DECL_COLLECTIONS.each do |coll|
          Array(schema.public_send(coll)).each do |decl|
            next unless decl.respond_to?(:id) && decl.id

            key = decl.id.safe_downcase
            if seen.key?(key)
              note!(:check_duplicate_declaration, :error, schema,
                    "duplicate declaration '#{decl.id}' (also declared in " \
                    "#{seen[key]})", decl)
            else
              seen[key] = coll.to_s
            end
          end
        end
      end

      # eeng: check-schema-interface-redundant +
      #       check-schema-iface-resource-duplicate.
      # USE FROM and REFERENCE FROM are different clauses with different
      # semantics; only interfaces of the SAME kind are compared.
      def check_interfaces(schema)
        ifaces = Array(schema.interfaces)
        ifaces.each_with_index do |iface, i|
          target = iface_schema_name(iface)
          next unless target

          later = ifaces[(i + 1)..] || []
          later.each do |other|
            next unless iface_schema_name(other)&.safe_downcase == target.safe_downcase
            next unless other.kind == iface.kind

            a = resource_names(iface)
            b = resource_names(other)
            if a.empty? || b.empty? || (b - a).empty?
              note!(:check_schema_interface_redundant, :warning, schema,
                    "redundant #{iface.kind} interface to #{target}", other)
            else
              dup = a & b
              next if dup.empty?

              note!(:check_schema_iface_resource_duplicate, :warning, schema,
                    "duplicate resources #{dup.join(', ')} on #{iface.kind} " \
                    "interface to #{target}", other)
            end
          end

          foreign = resolve_schema(target)
          unless foreign
            note!(:check_unresolved_ref, :error, schema,
                  "interface schema '#{target}' not found", iface)
            next
          end

          resource_names(iface).each do |name|
            decl = foreign_declaration(foreign, name)
            unless decl
              note!(:check_unresolved_ref, :error, schema,
                    "interface resource '#{name}' not in schema '#{target}'", iface)
              next
            end

            # eeng resolve-interface: use-from resolves via
            # find-type/entity, reference-from via the 5-kind or-chain;
            # anything else is "Resource '~A' not found".
            next if item_kind_interfacable?(iface.kind, decl)

            note!(:check_interface_kind_restriction, :error, schema,
                  "interface resource '#{name}' is a #{decl.class.name.split('::').last}: " + "#{iface.kind} resolves #{allowed_kinds(iface.kind)} only", iface)
          end
        end
      end

      def item_kind_interfacable?(kind, decl)
        (kind == Model::Declarations::Interface::REFERENCE ? REFERENCE_ITEM_KINDS : USE_ITEM_KINDS)
          .any? { |k| decl.is_a?(k) }
      end

      def allowed_kinds(kind)
        (kind == Model::Declarations::Interface::REFERENCE ? REFERENCE_ITEM_KINDS : USE_ITEM_KINDS)
          .map { |k| k.name.split("::").last }.join(", ")
      end

      def foreign_declaration(schema, name)
        key = name.safe_downcase
        DECL_COLLECTIONS.each do |coll|
          Array(schema.public_send(coll)).each do |d|
            return d if d.id&.safe_downcase == key
          end
        end
        nil
      end

      def iface_schema_name(iface)
        iface.schema.is_a?(String) ? iface.schema : iface.schema&.id
      end

      def resource_names(iface)
        Array(iface.items).filter_map do |item|
          ref = item.ref.is_a?(String) ? item.ref : item.ref&.id
          ref || item.id
        end.map(&:safe_downcase)
      end

      def foreign_decl?(schema, name)
        key = name.safe_downcase
        DECL_COLLECTIONS.any? do |coll|
          Array(schema.public_send(coll)).any? { |d| d.id&.safe_downcase == key }
        end
      end

      # eeng check-p11 context checks (kernel/check.lisp:160-201,
      # 299-336, 337-395): constant/local/parameter/return types must
      # resolve to a TYPE or ENTITY visible in the schema (find-type/
      # entity semantics - constants, functions, procedures do NOT
      # satisfy them). Note ids are the eeng ones.
      def check_type_resolutions(schema)
        schema.constants.each do |constant|
          check_type_ref(schema, Array(constant.type), :check_constant_type, constant.id, constant)
        end

        schema.functions.each do |function|
          Array(function.parameters).each do |param|
            check_type_ref(schema, Array(param.type), :check_parameter_type, param.id, param)
          end
          check_type_ref(schema, Array(function.return_type),
                         :check_function_return_type, function.id, function)
          Array(function.variables).each do |variable|
            check_type_ref(schema, Array(variable.type), :check_local_type, variable.id, variable)
          end
        end

        schema.procedures.each do |procedure|
          Array(procedure.parameters).each do |param|
            check_type_ref(schema, Array(param.type), :check_parameter_type, param.id, param)
          end
          Array(procedure.variables).each do |variable|
            check_type_ref(schema, Array(variable.type), :check_local_type, variable.id, variable)
          end
        end

        schema.rules.each do |rule|
          Array(rule.applies_to).each do |entity_ref|
            # parameter-rule: the FOR entities resolve via
            # find-type/entity too (kernel/check.lisp:311-322)
            check_entity_ref(schema, Array(entity_ref), :check_parameter_type, rule.id, rule)
          end
          Array(rule.variables).each do |variable|
            check_type_ref(schema, Array(variable.type), :check_local_type, variable.id, variable)
          end
        end
      end

      def check_type_ref(schema, nodes, note_id, name, node)
        nodes.each do |type|
          next unless type.is_a?(Model::References::SimpleReference)
          next if type.id.nil? || builtin?(type.id)
          next if resolves_to_type_or_entity?(schema, type.id)

          note!(note_id, :error, schema,
                "type '#{type.id}' of '#{name}' does not resolve to a type or entity", node || type)
        end
      end

      def check_entity_ref(schema, nodes, note_id, name, node)
        nodes.each do |ref|
          next unless ref.is_a?(Model::References::SimpleReference)
          next if ref.id.nil?
          next if resolves_to_type_or_entity?(schema, ref.id)

          note!(note_id, :error, schema,
                "entity '#{ref.id}' of '#{name}' does not resolve to a type or entity", node || ref)
        end
      end

      def resolves_to_type_or_entity?(schema, name)
        key = name.safe_downcase
        schema.children.any? do |child|
          next false unless child.id&.safe_downcase == key

          child.is_a?(Model::Declarations::Type) || child.is_a?(Model::Declarations::Entity) ||
            (child.is_a?(Model::Declarations::InterfacedItem) && interface_item_type_or_entity?(child))
        end
      end

      def interface_item_type_or_entity?(item)
        base = item.base_item
        base.is_a?(Model::Declarations::Type) || base.is_a?(Model::Declarations::Entity)
      end

      def check_entity(schema, entity)
        Array(entity.subtype_of).each do |ref|
          id = ref.is_a?(String) ? ref : ref.id
          next if id.nil? || find_entity(schema, id)

          note!(:check_subtype_ref, :error, schema,
                "ENTITY #{entity.id}: subtype '#{id}' not found", entity)
          next unless declared_kind(schema, id) == :type

          # eeng check-subtypeof-invalid: the name exists but is not
          # an entity, so it cannot be a supertype.
          note!(:check_subtypeof_invalid, :error, schema,
                "ENTITY #{entity.id}: subtype '#{id}' is a TYPE, " \
                "not an entity", entity)
        end
        check_supertype_refs(schema, entity)
        check_subtype_cycles(schema, entity)

        check_where_rules(schema, entity, entity.where_rules)
        check_inverse_attributes(schema, entity)
        check_group_references(schema, entity)
        Array(entity.unique_rules).each do |ur|
          next if ur.id.nil? || ur.id.match?(UNIQUE_LABEL)

          note!(:check_unique_name_pattern, :warning, schema,
                "ENTITY #{entity.id}: UNIQUE label '#{ur.id}' is not UR<n>", ur)
        end
      end

      # Cycle detection over SUBTYPE OF edges: per-path tracking with a
      # proven-acyclic memo, so convergent (diamond) branches are not
      # misread as cycles (#411).
      def check_subtype_cycles(schema, entity)
        walk_subtype_edges(schema, entity, entity,
                           [entity.id.safe_downcase], subtype_clean_memo(schema))
      end

      def subtype_clean_memo(schema)
        (@subtype_clean ||= {})[schema] ||= {}
      end

      # Returns true when a cycle is reachable from +node+; +path_keys+ is
      # the current DFS chain and +clean+ memoizes nodes proven acyclic.
      def walk_subtype_edges(schema, start, node, path_keys, clean)
        cyclic = false
        Array(node.subtype_of).each do |ref|
          id = ref.is_a?(String) ? ref : ref.id
          next unless id

          nxt = find_entity(schema, id)
          next unless nxt

          key = nxt.id.safe_downcase
          if path_keys.include?(key)
            note!(:check_subtype_cycle, :error, schema,
                  "ENTITY #{start.id}: subtype inheritance cycle through " \
                  "'#{nxt.id}'", start)
            cyclic = true
          elsif clean[key]
            next
          else
            cyclic ||= walk_subtype_edges(
              schema, start, nxt, path_keys + [key], clean
            )
          end
        end
        clean[node.id.safe_downcase] = true unless cyclic
        cyclic
      end

      # eeng check-supertype-ref: every entity named in the SUPERTYPE
      # expression must resolve to an entity of this schema.
      # eeng check-p11 subtype_constraint (kernel/check.lisp:426) only
      # checks the supertype expression; the note id matches the entity
      # supertype path (kernel/check.lisp:523).
      def explicit_attributes(entity)
        Array(entity.attributes)
          .select { |attr| attr.instance_of?(Model::Declarations::Attribute) }
      end

      # ---- tier 5: statement flow (13.2.1, 13.5, 13.6, 13.7) ----

      def statement_scopes(schema)
        Array(schema.functions) + Array(schema.procedures) +
          Array(schema.rules)
      end

      def check_statement_types(schema)
        statement_scopes(schema).each do |owner|
          @current_expression_env = expression_env(schema, owner)
          each_node(owner) do |node|
            case node
            when Model::Statements::Assignment
              check_assignment_type(schema, node)
            when Model::Statements::If
              check_logical_expression(schema, node.expression,
                                       "if condition (13.5)", node)
            when Model::Statements::Repeat
              check_repeat_types(schema, node)
            when Model::Statements::Return
              check_return_type(schema, owner, node)
            end
          end
        end
        @current_expression_env = nil
      end

      def check_assignment_type(schema, node)
        declared = static_type(schema, node.ref)
        expressed = static_type(schema, node.expression)
        return if undecidable?(declared, expressed)
        return if initializer_compatible?(schema, node.ref, declared,
                                          node.expression, expressed)

        note!(:check_expr_assignment_type, :error, schema,
              "assignment of #{expressed} to a #{declared} variable is " \
              "not compatible (13.2.1, 12.11)", node)
      end

      def check_logical_expression(schema, expression, label, node)
        t = static_type(schema, expression)
        return if undecidable?(t)
        return if LOGICAL_TYPES.include?(t)

        note!(:check_expr_operand_domain, :error, schema,
              "#{label} shall be a logical expression", node)
      end

      def check_repeat_types(schema, node)
        [node.while_expression, node.until_expression].compact.each do |condition|
          check_logical_expression(schema, condition,
                                   "repeat control condition (13.6)", node)
        end
        [node.bound1, node.bound2, node.increment].compact.each do |bound|
          t = static_type(schema, bound)
          next if undecidable?(t)
          next if NUMERIC_TYPES.include?(t)

          note!(:check_expr_operand_domain, :error, schema,
                "repeat increment control bounds shall be numeric " \
                "(13.6.1) (#{t})", bound)
        end
      end

      def check_return_type(schema, owner, node)
        unless owner.is_a?(Model::Declarations::Function)
          return unless node.expression

          note!(:check_expr_return, :error, schema,
                "a procedure return shall not specify an expression " \
                "(13.7)", node)
        end

        expression = node.expression
        return if expression.nil?
        return if owner.is_a?(Model::Declarations::Function) &&
          !owner.return_type

        declared = static_type(schema, owner.return_type)
        expressed = static_type(schema, expression)
        return if undecidable?(declared, expressed)
        return if initializer_compatible?(schema, owner.return_type,
                                          declared, expression, expressed)

        note!(:check_expr_return, :error, schema,
              "return expression #{expressed} is not compatible with " \
              "the declared return #{declared} (13.7, 12.11)", node)
      end

      # ---- tier 6: WHERE/UNIQUE structure (9.4) ----

      def check_rule_structure(schema)
        schema.entities.each do |entity|
          check_where_booleans(schema, entity, Array(entity.where_rules))
          check_unique_labels(schema, entity)
        end
        schema.types.each do |type|
          check_where_booleans(schema, type, Array(type.where_rules))
        end
        schema.rules.each do |rule|
          check_where_booleans(schema, rule, Array(rule.where_rules))
        end
      end

      def check_where_booleans(schema, owner, where_rules)
        @current_expression_env = expression_env(schema, owner)
        where_rules.each do |rule|
          t = static_type(schema, rule.expression)
          next if undecidable?(t)
          next if LOGICAL_TYPES.include?(t)

          note!(:check_expr_where_boolean, :error, schema,
                "WHERE '#{rule.id}' shall be a logical expression (9.4)", rule)
        end
        @current_expression_env = nil
      end

      def check_unique_labels(schema, entity)
        seen = {}
        Array(entity.unique_rules).each do |rule|
          key = rule.id&.safe_downcase
          next unless key

          if seen[key]
            note!(:check_expr_unique_duplicate, :error, schema,
                  "duplicate UNIQUE label '#{rule.id}' (9.4)", rule)
          end
          seen[key] = true
        end
      end

      def check_subtype_constraints(schema)
        schema.subtype_constraints.each do |constraint|
          expr = constraint.supertype_expression
          next unless expr

          each_reference(expr) do |ref|
            id = ref.id
            next if id.nil?
            # Names outside this schema's scope (foreign entities of a
            # single-file parse) cannot be verified here.
            next unless resolves_to_type_or_entity?(schema, id)
            next if find_entity(schema, id)

            note!(:check_supertype_ref, :error, schema,
                  "SUBTYPE_CONSTRAINT #{constraint.id}: supertype " \
                  "'#{id}' is not an entity", constraint)
          end
        end
      end

      # A `SELF\<supertype>.<attr>` redeclaration must name a supertype
      # in the inheritance closure carrying that attribute (ISO
      # 10303-11:2004, 9.2.2.3). eeng kernel/check.lisp:255 leaves this
      # as a TODO comment, so this check has no eeng note id.
      def check_attribute_redeclarations(schema, entity)
        explicit_attributes(entity).each do |attr|
          tag = attr.supertype_attribute
          next unless tag.is_a?(Model::References::AttributeReference)

          sup_id = tag.ref&.entity&.id
          attr_id = tag.attribute&.id
          if sup_id.nil?
            note!(:check_attribute_redeclaration, :error, schema,
                  "ENTITY #{entity.id}: redeclaration of '#{attr.id}' " \
                  "names no supertype", attr)
            next
          end

          supertype = entity.supertype_closure
            .find { |st| st.id&.safe_downcase == sup_id.safe_downcase }
          if supertype.nil?
            # The named supertype may be foreign (USE FROM) and thus
            # outside the closure of a single-file parse; only flag it
            # when it resolves in this scope yet is not a supertype.
            if find_entity(schema, sup_id)
              note!(:check_attribute_redeclaration, :error, schema,
                    "ENTITY #{entity.id}: redeclaration '#{attr.id}' names " \
                    "'#{sup_id}', which is not a supertype", attr)
            end
            next
          end

          next if explicit_attributes(supertype)
            .any? { |candidate| candidate.id&.safe_downcase == attr_id&.safe_downcase }

          note!(:check_attribute_redeclaration, :error, schema,
                "ENTITY #{entity.id}: redeclaration '#{attr.id}': supertype " \
                "'#{sup_id}' has no attribute '#{attr_id}'", attr)
        end
      end

      def check_supertype_refs(schema, entity)
        expr = entity.supertype_expression
        return unless expr

        each_reference(expr) do |ref|
          id = ref.id
          next if id.nil? || find_entity(schema, id)

          note!(:check_supertype_ref, :error, schema,
                "ENTITY #{entity.id}: supertype '#{id}' not found", entity)
        end
      end

      # eeng check-inverse-* (ISO 10303-11 9.2.1.4): every INVERSE
      # attribute must name a real entity and pair with a real
      # attribute on it — one that is neither DERIVE nor itself an
      # INVERSE — whose domain includes the owning entity (through
      # subtype relations and nested aggregates). check-inverse-agg
      # (only SET/BAG may aggregate an inverse) is structurally
      # impossible here: the grammar rejects other aggregate kinds.
      def check_inverse_attributes(schema, entity)
        entity.attributes.to_a
          .grep(Model::Declarations::InverseAttribute)
          .each { |inv| check_inverse_attribute(schema, entity, inv) }
      end

      def check_inverse_attribute(schema, entity, inv)
        target = inverse_target(schema, inv)
        if target.nil?
          note!(:check_inverse_entity, :error, schema,
                "ENTITY #{entity.id}: INVERSE '#{inv.id}' target " \
                "'#{inverse_target_id(inv)}' is not an entity", inv)
          return
        end

        attr_id = inverse_paired_attr_id(inv)
        if attr_id.nil?
          note!(:check_inverse_attrib_ref, :error, schema,
                "ENTITY #{entity.id}: INVERSE '#{inv.id}' names no " \
                "attribute after FOR", inv)
          return
        end

        owner = inverse_attr_owner(schema, inv, target)
        paired = owner && attribute_on_closure(schema, owner, attr_id)
        if paired.nil?
          note!(:check_inverse_attrib_ref, :error, schema,
                "ENTITY #{entity.id}: INVERSE '#{inv.id}': entity " \
                "'#{owner&.id || target.id}' has no attribute '#{attr_id}'", inv)
          return
        end

        if paired.is_a?(Model::Declarations::InverseAttribute)
          note!(:check_inverse_inverse, :error, schema,
                "ENTITY #{entity.id}: INVERSE '#{inv.id}' pairs with " \
                "'#{owner.id}.#{attr_id}', which is itself an INVERSE", inv)
        elsif paired.kind == Expressir::Model::Declarations::Attribute::DERIVED
          note!(:check_inverse_derive, :error, schema,
                "ENTITY #{entity.id}: INVERSE '#{inv.id}' pairs with " \
                "'#{owner.id}.#{attr_id}', which is a DERIVE", inv)
        end
      end

      def inverse_target(schema, inv)
        type = inv.type
        type = type.base_type if type.respond_to?(:base_type)
        return nil unless type.respond_to?(:id)

        find_entity(schema, ref_id(type))
      end

      def inverse_target_id(inv)
        type = inv.type
        type = type.base_type if type.respond_to?(:base_type)
        ref_id(type)
      end

      # The entity the FOR-attribute lives on: the qualified
      # `e.a FOR` form overrides the type's entity.
      def inverse_attr_owner(schema, inv, target)
        expr = inv.expression
        if expr.is_a?(Model::References::AttributeReference) &&
            expr.ref.respond_to?(:id)
          find_entity(schema, ref_id(expr.ref)) || target
        else
          target
        end
      end

      def inverse_paired_attr_id(inv)
        expr = inv.expression
        return ref_id(expr) if expr.respond_to?(:id)

        expr.respond_to?(:attribute) ? ref_id(expr.attribute) : nil
      end

      # Attribute on +entity+ or any of its supertype ancestors.
      def attribute_on_closure(schema, entity, attr_id)
        key = attr_id.safe_downcase
        seen = {}.compare_by_identity
        queue = [entity]
        until queue.empty?
          current = queue.shift
          next if seen[current]

          seen[current] = true
          hit = Array(current.attributes).find do |a|
            a.id&.safe_downcase == key
          end
          return hit if hit

          Array(current.subtype_of).each do |ref|
            id = ref_id(ref)
            next unless id

            target = find_entity(schema, id)
            queue << target if target
          end
        end
        nil
      end

      # eeng qualified-attrib-* (ISO 10303-11 12.7.4). The group must
      # resolve to an entity and the qualified attribute must exist on
      # it. The ANCESTRY requirement applies only to redeclared
      # attributes (SELF\T.attr as an attribute declaration) — eeng
      # checks exactly those; TYPEOF-guarded sibling views in
      # expressions (geometry_schema's SELF\subface.parent_face) are
      # standard corpus usage and are not flagged.
      def check_group_references(schema, entity)
        closure = supertype_closure_ids(schema, entity)
        closure << entity.id if entity.id
        redeclared = {}.compare_by_identity
        entity.attributes.to_a.each do |attr|
          sa = attr.supertype_attribute
          next unless sa.is_a?(Model::References::AttributeReference) &&
            sa.ref.is_a?(Model::References::GroupReference)

          redeclared[sa.ref] = true
          group = sa.ref
          target = resolve_group(schema, entity, group)
          next if target.nil?
          next if closure.include?(ref_id(group.entity)&.safe_downcase)

          note!(:qualified_attrib_group_not_ancestor, :error, schema,
                "ENTITY #{entity.id}: SELF\\'#{ref_id(group.entity)}' " \
                "is not a supertype of #{entity.id}", group)
        end

        each_node(entity) do |node|
          next unless node.is_a?(Model::References::GroupReference)
          next if redeclared[node]

          target = resolve_group(schema, entity, node)
          next if target.nil?

          parent = node.parent
          attr_id = parent.respond_to?(:attribute) ? ref_id(parent.attribute) : nil
          next if attr_id.nil?
          next if Array(target.attributes).any? do |a|
            a.id&.safe_downcase == attr_id.safe_downcase
          end

          note!(:qualified_attrib_attr_not_found, :error, schema,
                "ENTITY #{entity.id}: '#{ref_id(node.entity)}.#{attr_id}': " \
                "'#{ref_id(node.entity)}' has no attribute '#{attr_id}'", node)
        end
      end

      # Resolve a group qualifier's entity, noting
      # qualified-attrib-group-not-found when it does not resolve.
      def resolve_group(schema, entity, node)
        group_id = ref_id(node.entity)
        target = group_id && find_entity(schema, group_id)
        return target if target

        note!(:qualified_attrib_group_not_found, :error, schema,
              "ENTITY #{entity.id}: group '#{group_id}' in a qualified " \
              "attribute does not resolve to an entity", node)
        nil
      end

      def supertype_closure_ids(schema, entity)
        seen = {}.compare_by_identity
        queue = [entity]
        ids = []
        until queue.empty?
          current = queue.shift
          next if seen[current]

          seen[current] = true
          Array(current.subtype_of).each do |ref|
            id = ref_id(ref)
            next if id.nil?

            ids << id
            parent = find_entity(schema, id)
            queue << parent if parent
          end
        end
        ids
      end

      def each_reference(node, &block)
        case node
        when Model::References::SimpleReference then yield node
        when Model::ModelElement
          node.class.attributes.each_key do |attr|
            next if Model::ModelElement::SKIP_ATTRIBUTES.include?(attr) || attr == :parent

            value = node.public_send(attr)
            case value
            when Array then value.each { |item| each_reference(item, &block) }
            when Model::ModelElement then each_reference(value, &block)
            end
          end
        end
      end

      # eeng check-select-named-type: SELECT items must name types.
      def check_select_items(schema, type)
        return unless type.underlying_type.is_a?(Model::DataTypes::Select)

        Array(type.underlying_type.items).each do |item|
          next if item.id.nil?
          next if select_item_resolves?(schema, item.id)

          note!(:check_select_named_type, :error, schema,
                "In the SELECT TYPE #{type.id}, '#{item.id}' does not " \
                "name an existing TYPE or ENTITY", type)
        end
      end

      def find_type(schema, id)
        key = id.safe_downcase
        schema.types.find { |t| t.id.safe_downcase == key }
      end

      # ISO 10303-11 rule 258: select_list items are named_types —
      # entity_ref | type_ref. The item is fine when it names either,
      # in this schema or any repository schema (interface-visible).
      def select_item_resolves?(schema, id)
        return true if find_entity(schema, id)
        return true if schema.types.to_a.any? { |t| t.id.safe_downcase == id.safe_downcase }

        @by_name.each_value.any? do |group|
          group.any? do |other|
            other.types.to_a.any? { |t| t.id.safe_downcase == id.safe_downcase } ||
              other.entities.to_a.any? { |e| e.id.safe_downcase == id.safe_downcase }
          end
        end
      end

      # eeng declared-kind probe: :type when a TYPE of that name is
      # visible in the schema (used to separate not-found from
      # not-an-entity in subtype diagnostics).
      def declared_kind(schema, id)
        :type if find_type(schema, id)
      end

      # eeng check-agg-type: a two-bound aggregate whose lower bound
      # exceeds its upper bound is invalid.
      def check_aggregate_bounds(schema, entity)
        entity.attributes.to_a.each do |attr|
          type = attr.type
          next unless type.respond_to?(:bound1) && type.respond_to?(:bound2)

          lower = integer_bound(type.bound1)
          upper = integer_bound(type.bound2)
          next if lower.nil? || upper.nil?
          next if lower <= upper

          note!(:check_agg_type, :error, schema,
                "ENTITY #{entity.id}: aggregate '#{attr.id}' bounds " \
                "[#{lower}:#{upper}] are inverted", attr)
        end
      end

      def integer_bound(bound)
        return nil unless bound.is_a?(Model::Literals::Integer)

        bound.value.to_i
      rescue StandardError
        nil
      end

      # eeng check-attrib-name-fun: an attribute sharing its name with
      # a function of the same schema can never be referenced cleanly.
      def check_attrib_name_fun(schema, entity)
        funs = schema.functions.to_a.map { |f| f.id.safe_downcase }
        entity.attributes.to_a.each do |attr|
          next unless attr.id && funs.include?(attr.id.safe_downcase)

          note!(:check_attrib_name_fun, :warning, schema,
                "ENTITY #{entity.id}: attribute '#{attr.id}' shadows a " \
                "function of the same name", attr)
        end
      end

      # eeng check-string-no-entity: string literals of the shape
      # 'SCHEMA.ITEM' whose SCHEMA is known in the repository but whose
      # ITEM is not declared in it (the TYPEOF idiom).
      def check_string_references(schema)
        known = @by_name
        each_string(schema) do |literal, value|
          match = /\A(\w+)\.(\w+)\z/.match(value)
          next unless match

          schema_id = match[1].safe_downcase
          item_id = match[2].safe_downcase
          target = known[schema_id]&.find { |s| s.id.safe_downcase == schema_id }
          next unless target
          next if Expressir::Express::SelfSchemaReference.declared?(target, item_id)

          note!(:check_string_no_entity, :warning, schema,
                "string '#{value}' references '#{item_id}' which is not " \
                "declared in schema '#{target.id}'", literal)
        end
      end

      def each_string(node, &block)
        case node
        when Model::Literals::String then yield node, node.value
        when Model::ModelElement
          node.class.attributes.each_key do |attr|
            next if Model::ModelElement::SKIP_ATTRIBUTES.include?(attr) || attr == :parent

            value = node.public_send(attr)
            case value
            when Array then value.each { |item| each_string(item, &block) }
            when Model::ModelElement then each_string(value, &block)
            end
          end
        end
      end

      def check_where_rules(schema, owner, rules)
        Array(rules).each do |wr|
          next if wr.id.nil? || wr.id.match?(WHERE_LABEL)

          note!(:check_where_name_pattern, :warning, schema,
                "#{owner.class.name.split('::').last} #{owner.id}: " \
                "WHERE label '#{wr.id}' is not WR<n>", wr)
        end
      end

      def check_type(schema, type)
        ut = type.underlying_type
        case ut
        when Model::DataTypes::Select
          if ut.based_on && !resolve_type(schema, ut.based_on)
            note!(:check_select_extended_type, :error, schema,
                  "TYPE #{type.id}: BASED_ON '#{ref_id(ut.based_on)}' not found", type)
          end
        when Model::DataTypes::Enumeration
          if ut.based_on && !resolve_type(schema, ut.based_on)
            note!(:check_enumeration_extended_type, :error, schema,
                  "TYPE #{type.id}: BASED_ON '#{ref_id(ut.based_on)}' not found", type)
          end
        end
      end

      # Walk SimpleReferences whose base_path was never filled in by the
      # resolver — the expressir equivalent of eeng's unparsed-type notes.
      # Locally bound identifiers are not unresolved: QUERY variables,
      # REPEAT control variables, attribute names visible in the schema,
      # and the `?` of aggregate bounds (#396).
      def check_unresolved_refs(schema)
        aliases = alias_map(schema)
        bound = bound_identifiers(schema)
        each_node(schema) do |node|
          next unless node.is_a?(Model::References::SimpleReference)
          next if node.base_path
          next if node.parent.is_a?(Model::Declarations::InterfaceItem)
          next if node.parent.is_a?(Model::References::AttributeReference)
          next if node.id.nil? || builtin?(node.id)
          next if aliases.key?(node.id.safe_downcase)
          next if bound.include?(node.id.safe_downcase)

          # Skip self-ids of declarations (entity/type names as the decl itself)
          next if declaration_id?(schema, node)

          note!(:check_unresolved_ref, :error, schema,
                "unresolved reference '#{node.id}'", node)
        end
      end

      # Names the schema's own constructs bind: QUERY variables, REPEAT
      # control variables, attribute names of every entity (including the
      # inherited ones visible through SUBTYPE OF — an over-approximation on
      # purpose, so the error-severity walk never flags a legal identifier).
      def bound_identifiers(schema)
        @bound_identifiers ||= {}.compare_by_identity
        @bound_identifiers[schema] ||= begin
          bound = Set.new(["?"])
          each_node(schema) do |node|
            case node
            when Model::Expressions::QueryExpression, Model::Statements::Repeat
              bound << node.id.safe_downcase if node.respond_to?(:id) && node.id
            end
          end
          schema.entities.each { |e| collect_attribute_names(e, bound) }
          visible_entities(schema).each { |e| collect_attribute_names(e, bound) }
          bound
        end
      end

      def collect_attribute_names(entity, bound)
        Array(entity.attributes).each do |attr|
          bound << attr.id.safe_downcase if attr.respond_to?(:id) && attr.id
        end
      end

      # `USE FROM s (orig AS alias)` makes `alias` the locally visible name;
      # references written with the alias are resolved, not unresolved.
      # Maps alias downcase => [foreign schema, original downcase].
      def alias_map(schema)
        @alias_maps ||= {}.compare_by_identity
        @alias_maps[schema] ||= begin
          map = {}
          Array(schema.interfaces).each do |iface|
            foreign = resolve_schema(iface_schema_name(iface))
            next unless foreign

            Array(iface.items).each do |item|
              original = item.ref.is_a?(String) ? item.ref : item.ref&.id
              next unless original && item.id

              map[item.id.safe_downcase] = [foreign, original.safe_downcase]
            end
          end
          map
        end
      end

      def declaration_id?(_schema, node)
        parent = node.parent
        parent.respond_to?(:id) && parent.id&.safe_downcase == node.id.safe_downcase
      end

      def builtin?(id)
        BUILTINS.include?(id.safe_downcase)
      end

      # Resolve a schema id case-insensitively, preferring the exact-case
      # match when several folded ids collide (they are distinct schemas).
      def resolve_schema(name)
        return nil unless name

        group = @by_name[name.safe_downcase]
        return nil unless group

        group.find { |s| s.id == name } || group.first
      end

      def find_entity(schema, id)
        key = id.safe_downcase
        own = schema.entities.find { |e| e.id.safe_downcase == key }
        return own if own

        # interface AS-renames: the alias names a foreign declaration.
        if (aliased = alias_map(schema)[key])
          foreign, original = aliased
          return foreign.entities.find { |e| e.id.safe_downcase == original }
        end

        visible_entities(schema).find { |e| e.id.safe_downcase == key }
      end

      def resolve_type(schema, ref)
        id = ref_id(ref)
        return false unless id

        key = id.safe_downcase
        own = schema.types.find { |t| t.id.safe_downcase == key }
        return true if own

        if (aliased = alias_map(schema)[key])
          foreign, original = aliased
          return foreign.types.any? { |t| t.id.safe_downcase == original }
        end

        visible_types(schema).any? { |t| t.id.safe_downcase == key }
      end

      def ref_id(ref)
        ref.is_a?(String) ? ref : ref&.id
      end

      # Foreign declarations visible through +schema+'s interfaces. With an
      # item list, the LISTED names are AS-imported: match the originals.
      def visible_from(schema, collection)
        Array(schema.interfaces).flat_map do |iface|
          foreign = resolve_schema(iface_schema_name(iface))
          next [] unless foreign

          names = resource_names(iface)
          decls = Array(foreign.public_send(collection))
          names.empty? ? decls : decls.select { |d| names.include?(d.id.safe_downcase) }
        end
      end

      def visible_entities(schema)
        visible_from(schema, :entities)
      end

      def visible_types(schema)
        visible_from(schema, :types)
      end

      def each_node(root)
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
    end
  end
end
