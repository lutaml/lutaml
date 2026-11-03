# frozen_string_literal: true

# Centralized Builder Registry
# ============================
# This is the SINGLE SOURCE OF TRUTH for all AST node type registrations.
#
# Builder classes are defined in types/*.rb files.
# This file creates instances and registers them with Builder.register.
#
# Benefits of this architecture:
# 1. All registrations in one place - easy to see what's handled
# 2. Separation of class definition from registration
# 3. Multiple type configurations possible

module Expressir
  module Express
    # Builder registry module - creates instances and registers handlers
    module BuilderRegistry
      # Create type instances (used by closures below)
      built_in = Builders::BuiltInBuilder.new
      constant = Builders::ConstantBuilder.new
      expression = Builders::ExpressionBuilder.new
      interface = Builders::InterfaceBuilder.new
      literal = Builders::LiteralBuilder.new
      qualifier = Builders::QualifierBuilder.new
      statement = Builders::StatementBuilder.new
      subtype_constraint = Builders::SubtypeConstraintBuilder.new
      type_builder = Builders::TypeBuilder.new

      # ========================================================================
      # Token Operators (return nil - used as separators)
      # Token types - operator tokens that return nil.
      # These are used as separators in lists and don't produce model objects.
      # ========================================================================
      %i[
        op_comma op_colon op_decl op_delim op_leftparen op_rightparen
        op_leftbracket op_rightbracket op_left_curly_brace op_right_curly_brace
        op_period op_pipe op_double_backslash op_double_pipe op_double_asterisk
        op_asterisk op_slash op_plus op_minus op_less_equal op_greater_equal
        op_less_greater op_less_than op_greater_than op_equals
        op_colon_less_greater_colon op_colon_equals_colon
        op_query_begin op_query_end op_question_mark
      ].each do |token|
        Builder.register(token) { |_d| nil }
      end

      # ========================================================================
      # Simple ID Types (return string via SimpleIdBuilder)
      # ========================================================================
      %i[
        simple_id schema_id entity_id type_id function_id procedure_id
        rule_id rule_label_id constant_id parameter_id variable_id
        enumeration_id subtype_constraint_id type_label_id attribute_id
      ].each do |id_type|
        Builder.register(id_type, Builders::SimpleIdBuilder.new)
      end

      # ========================================================================
      # Reference Types (return SimpleReference via ReferenceBuilder)
      # ========================================================================
      %i[
        attribute_ref constant_ref entity_ref enumeration_ref function_ref
        parameter_ref procedure_ref rule_ref rule_label_ref schema_ref
        subtype_constraint_ref type_label_ref type_ref variable_ref
      ].each do |ref_type|
        Builder.register(ref_type, Builders::ReferenceBuilder.new)
      end

      # ========================================================================
      # Class-based Builders (simple delegation to call method)
      # ========================================================================
      Builder.register(:syntax, Builders::SyntaxBuilder.new)
      Builder.register(:schema_version_id, Builders::SchemaVersionBuilder.new)
      Builder.register(:declaration, Builders::DeclarationBuilder.new)
      Builder.register(:schema_body_declaration, Builders::SchemaBodyDeclBuilder.new)
      Builder.register(:schema_decl, Builders::SchemaDeclBuilder.new)
      Builder.register(:entity_decl, Builders::EntityDeclBuilder.new)
      Builder.register(:explicit_attr, Builders::ExplicitAttrBuilder.new)
      Builder.register(:attribute_decl, Builders::AttributeDeclBuilder.new)
      Builder.register(:derive_clause, Builders::DeriveClauseBuilder.new)
      Builder.register(:derived_attr, Builders::DerivedAttrBuilder.new)
      Builder.register(:inverse_clause, Builders::InverseClauseBuilder.new)
      Builder.register(:inverse_attr, Builders::InverseAttrBuilder.new)
      Builder.register(:inverse_attr_type, Builders::InverseAttrTypeBuilder.new)
      Builder.register(:unique_clause, Builders::UniqueClauseBuilder.new)
      Builder.register(:unique_rule, Builders::UniqueRuleBuilder.new)
      Builder.register(:where_clause, Builders::WhereClauseBuilder.new)
      Builder.register(:domain_rule, Builders::DomainRuleBuilder.new)
      Builder.register(:type_decl, Builders::TypeDeclBuilder.new)
      Builder.register(:function_decl, Builders::FunctionDeclBuilder.new)
      Builder.register(:procedure_decl, Builders::ProcedureDeclBuilder.new)
      Builder.register(:rule_decl, Builders::RuleDeclBuilder.new)

      # ========================================================================
      # Built-in Builder (closures)
      # ========================================================================
      Builder.register(:built_in_constant) do |d|
        built_in.build_built_in_constant(d)
      end
      Builder.register(:built_in_function) do |d|
        built_in.build_built_in_function(d)
      end
      Builder.register(:built_in_procedure) do |d|
        built_in.build_built_in_procedure(d)
      end
      Builder.register(:general_ref) { |d| built_in.build_general_ref(d) }
      Builder.register(:named_types) { |d| built_in.build_named_types(d) }
      Builder.register(:item) { |d| built_in.build_item(d) }
      Builder.register(:procedure_ref) { |d| built_in.build_procedure_ref(d) }
      Builder.register(:schema_ref) { |d| built_in.build_schema_ref(d) }

      # ========================================================================
      # Constant Builder (closures)
      # ========================================================================
      Builder.register(:constant_decl) { |d| constant.build_constant_decl(d) }
      Builder.register(:constant_body) { |d| constant.build_constant_body(d) }
      Builder.register(:local_decl) { |d| constant.build_local_decl(d) }
      Builder.register(:local_variable) { |d| constant.build_local_variable(d) }
      Builder.register(:formal_parameter) do |d|
        constant.build_formal_parameter(d)
      end
      Builder.register(:procedure_head_parameter) do |d|
        constant.build_procedure_head_parameter(d)
      end

      # ========================================================================
      # Expression Builder (closures)
      # ========================================================================
      Builder.register(:expression) { |d| expression.build_expression(d) }
      Builder.register(:logical_expression) do |d|
        expression.build_logical_expression(d)
      end
      Builder.register(:numeric_expression) do |d|
        expression.build_numeric_expression(d)
      end
      Builder.register(:simple_expression) do |d|
        expression.build_simple_expression(d)
      end
      Builder.register(:term) { |d| expression.build_term(d) }
      Builder.register(:factor) { |d| expression.build_factor(d) }
      Builder.register(:simple_factor) { |d| expression.build_simple_factor(d) }
      Builder.register(:simple_factor_expression) do |d|
        expression.build_simple_factor_expression(d)
      end
      Builder.register(:simple_factor_unary_expression) do |d|
        expression.build_simple_factor_unary_expression(d)
      end
      Builder.register(:constant_factor) do |d|
        expression.build_constant_factor(d)
      end
      Builder.register(:primary) { |d| expression.build_primary(d) }
      Builder.register(:qualifiable_factor) do |d|
        expression.build_qualifiable_factor(d, nil)
      end
      Builder.register(:population) { |d| expression.build_population(d, nil) }
      Builder.register(:qualifier) { |d| expression.build_qualifier(d) }
      Builder.register(:rel_op_extended) do |d|
        expression.build_rel_op_extended(d)
      end
      Builder.register(:function_call) { |d| expression.build_function_call(d) }
      Builder.register(:actual_parameter_list) do |d|
        expression.build_actual_parameter_list(d)
      end
      Builder.register(:parameter) { |d| expression.build_parameter(d) }
      Builder.register(:entity_constructor) do |d|
        expression.build_entity_constructor(d)
      end
      Builder.register(:query_expression) do |d|
        expression.build_query_expression(d)
      end
      Builder.register(:aggregate_source) do |d|
        expression.build_aggregate_source(d)
      end
      Builder.register(:aggregate_initializer) do |d|
        expression.build_aggregate_initializer(d)
      end
      Builder.register(:element) { |d| expression.build_element(d) }
      Builder.register(:repetition) { |d| expression.build_repetition(d) }
      Builder.register(:interval) { |d| expression.build_interval(d) }
      Builder.register(:interval_low) { |d| expression.build_interval_low(d) }
      Builder.register(:interval_high) { |d| expression.build_interval_high(d) }
      Builder.register(:interval_item) { |d| expression.build_interval_item(d) }
      Builder.register(:interval_op) do |d|
        expression.extract_interval_op(d)
      end

      # Operators
      Builder.register(:add_like_op) do |d|
        expression.extract_operator(d)
      end
      Builder.register(:mul_like_op) do |d|
        expression.extract_operator(d)
      end
      Builder.register(:unary_op) { |d| expression.extract_unary_op(d) }
      Builder.register(:rel_op) { |d| expression.extract_rel_op(d) }

      # ========================================================================
      # Interface Builder (closures)
      # ========================================================================
      Builder.register(:interface_specification) do |d|
        interface.build_interface_specification(d)
      end
      Builder.register(:use_clause) { |d| interface.build_use_clause(d) }
      Builder.register(:reference_clause) do |d|
        interface.build_reference_clause(d)
      end
      Builder.register(:named_type_or_rename) do |d|
        interface.build_named_type_or_rename(d)
      end
      Builder.register(:resource_or_rename) do |d|
        interface.build_resource_or_rename(d)
      end
      Builder.register(:resource_ref) { |d| interface.build_resource_ref(d) }
      Builder.register(:rename_id) { |d| interface.build_rename_id(d) }

      # ========================================================================
      # Literal Builder (closures)
      # ========================================================================
      Builder.register(:integer_literal) { |d| literal.build_integer(d) }
      Builder.register(:real_literal) { |d| literal.build_real(d) }
      Builder.register(:binary_literal) { |d| literal.build_binary(d) }
      Builder.register(:logical_literal) { |d| literal.build_logical(d) }
      Builder.register(:string_literal) { |d| literal.build_string(d) }
      Builder.register(:simple_string_literal) do |d|
        literal.build_simple_string(d)
      end
      Builder.register(:encoded_string_literal) do |d|
        literal.build_encoded_string(d)
      end
      Builder.register(:literal, literal)

      # ========================================================================
      # Qualifier Builder (closures)
      # ========================================================================
      Builder.register(:redeclared_attribute) do |d|
        qualifier.build_redeclared_attribute(d)
      end
      Builder.register(:referenced_attribute) do |d|
        qualifier.build_referenced_attribute(d)
      end
      Builder.register(:qualified_attribute) do |d|
        qualifier.build_qualified_attribute(d)
      end
      Builder.register(:group_qualifier) do |d|
        qualifier.build_group_qualifier(d)
      end
      Builder.register(:attribute_qualifier) do |d|
        qualifier.build_attribute_qualifier(d)
      end
      Builder.register(:index_qualifier) do |d|
        qualifier.build_index_qualifier(d)
      end
      Builder.register(:index1) { |d| qualifier.build_index1(d) }
      Builder.register(:index2) { |d| qualifier.build_index2(d) }
      Builder.register(:index) { |d| qualifier.build_index(d) }
      Builder.register(:enumeration_reference) do |d|
        qualifier.build_enumeration_reference(d)
      end

      # ========================================================================
      # Statement Builder (closures)
      # ========================================================================
      Builder.register(:stmt) { |d| statement.build_stmt(d) }
      Builder.register(:assignment_stmt) do |d|
        statement.build_assignment_stmt(d)
      end
      Builder.register(:alias_stmt) { |d| statement.build_alias_stmt(d) }
      Builder.register(:if_stmt) { |d| statement.build_if_stmt(d) }
      Builder.register(:case_stmt) { |d| statement.build_case_stmt(d) }
      Builder.register(:selector) { |d| statement.build_selector(d) }
      Builder.register(:case_action) { |d| statement.build_case_action(d) }
      Builder.register(:case_label) { |d| statement.build_case_label(d) }
      Builder.register(:compound_stmt) { |d| statement.build_compound_stmt(d) }
      Builder.register(:repeat_stmt) { |d| statement.build_repeat_stmt(d) }
      Builder.register(:increment_control) do |d|
        statement.build_increment_control(d)
      end
      Builder.register(:increment) { |d| statement.build_increment(d) }
      Builder.register(:while_control) { |d| statement.build_while_control(d) }
      Builder.register(:until_control) { |d| statement.build_until_control(d) }
      Builder.register(:return_stmt) { |d| statement.build_return_stmt(d) }
      Builder.register(:escape_stmt) { |d| statement.build_escape_stmt(d) }
      Builder.register(:skip_stmt) { |d| statement.build_skip_stmt(d) }
      Builder.register(:null_stmt) { |d| statement.build_null_stmt(d) }
      Builder.register(:procedure_call_stmt) do |d|
        statement.build_procedure_call_stmt(d)
      end
      Builder.register(:type_label) { |d| statement.build_type_label(d) }
      Builder.register(:type_label_ref) do |d|
        statement.build_type_label_ref(d)
      end

      # ========================================================================
      # Subtype Constraint Builder (closures)
      # ========================================================================
      Builder.register(:subtype_constraint_decl) do |d|
        subtype_constraint.build_subtype_constraint_decl(d)
      end
      Builder.register(:subtype_constraint) do |d|
        subtype_constraint.build_subtype_constraint(d)
      end
      Builder.register(:subtype_declaration) do |d|
        subtype_constraint.build_subtype_declaration(d)
      end
      Builder.register(:supertype_rule) do |d|
        subtype_constraint.build_supertype_rule(d)
      end
      Builder.register(:supertype_expression) do |d|
        subtype_constraint.build_supertype_expression(d)
      end
      Builder.register(:supertype_factor) do |d|
        subtype_constraint.build_supertype_factor(d)
      end
      Builder.register(:supertype_term) do |d|
        subtype_constraint.build_supertype_term(d)
      end
      Builder.register(:one_of) { |d| subtype_constraint.build_one_of(d) }
      Builder.register(:total_over) do |d|
        subtype_constraint.build_total_over(d)
      end

      # ========================================================================
      # Type Builder (closures)
      # ========================================================================

      # Simple types
      Builder.register(:boolean_type) { |d| type_builder.build_boolean_type(d) }
      # GENERIC[: label] / GENERIC_ENTITY[: label] — ISO 10303-11
      # 9.5.3.2 type label (GH-339).
      def self.type_label_id(ast_data)
        label = ast_data.is_a?(Hash) ? ast_data[:type_label] : nil
        return nil unless label.is_a?(Hash)

        Builder.build_optional({ simple_id: label[:type_label_id][:simple_id] })
      end

      Builder.register(:integer_type) { |d| type_builder.build_integer_type(d) }
      Builder.register(:logical_type) { |d| type_builder.build_logical_type(d) }
      Builder.register(:number_type) { |d| type_builder.build_number_type(d) }

      # Type constructors
      Builder.register(:generic_type) { |d| Expressir::Model::DataTypes::Generic.new(id: BuilderRegistry.type_label_id(d)) }
      Builder.register(:generic_entity_type) { |d| Expressir::Model::DataTypes::GenericEntity.new(id: BuilderRegistry.type_label_id(d)) }
      Builder.register(:aggregate_type) do |d|
        type_builder.build_aggregate_type(d)
      end
      Builder.register(:general_set_type) do |d|
        type_builder.build_general_set_type(d)
      end
      Builder.register(:general_list_type) do |d|
        type_builder.build_general_list_type(d)
      end
      Builder.register(:general_bag_type) do |d|
        type_builder.build_general_bag_type(d)
      end
      Builder.register(:general_array_type) do |d|
        type_builder.build_general_array_type(d)
      end

      Builder.register(:string_type) { |d| type_builder.build_string_type(d) }
      Builder.register(:binary_type) { |d| type_builder.build_binary_type(d) }
      Builder.register(:real_type) { |d| type_builder.build_real_type(d) }
      Builder.register(:array_type) { |d| type_builder.build_array_type(d) }
      Builder.register(:bag_type) { |d| type_builder.build_bag_type(d) }
      Builder.register(:list_type) { |d| type_builder.build_list_type(d) }
      Builder.register(:set_type) { |d| type_builder.build_set_type(d) }
      Builder.register(:enumeration_type) do |d|
        type_builder.build_enumeration_type(d)
      end
      Builder.register(:enumeration_item) do |d|
        type_builder.build_enumeration_item(d)
      end
      Builder.register(:select_type) { |d| type_builder.build_select_type(d) }

      # Type wrappers
      %i[concrete_types simple_types aggregation_types constructed_types
         generalized_types named_types instantiable_type parameter_type
         underlying_type general_aggregation_types].each do |type|
        Builder.register(type) { |d| type_builder.build_type_wrapper(d) }
      end

      # Bound handlers
      Builder.register(:bound1) do |d|
        Builder.build_optional(d[:numeric_expression])
      end
      Builder.register(:bound2) do |d|
        Builder.build_optional(d[:numeric_expression])
      end
      Builder.register(:width_spec) do |d|
        { width: Builder.build_optional(d[:width]), fixed: !d[:t_fixed].nil? }
      end
      Builder.register(:width) do |d|
        Builder.build_optional(d[:numeric_expression])
      end
    end
  end
end
