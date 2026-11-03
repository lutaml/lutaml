# frozen_string_literal: true

# Builder loader - requires all builder classes.
# This file has NO CODE, only requires.
# Each builder class registers itself with Builder.register.

# Ensure Expressir module and autoloads are set up first
module Expressir
  module Express
    module Builders
      autoload :Helpers, "#{__dir__}/builders/helpers"

      autoload :TokenBuilder, "#{__dir__}/builders/token_builder"
      autoload :SimpleIdBuilder, "#{__dir__}/builders/simple_id_builder"
      autoload :SyntaxBuilder, "#{__dir__}/builders/syntax_builder"
      autoload :SchemaVersionBuilder,
               "#{__dir__}/builders/schema_version_builder"
      autoload :DeclarationBuilder, "#{__dir__}/builders/declaration_builder"
      autoload :SchemaBodyDeclBuilder,
               "#{__dir__}/builders/schema_body_decl_builder"
      autoload :SchemaDeclBuilder, "#{__dir__}/builders/schema_decl_builder"
      autoload :EntityDeclBuilder, "#{__dir__}/builders/entity_decl_builder"
      autoload :ExplicitAttrBuilder, "#{__dir__}/builders/explicit_attr_builder"
      autoload :AttributeDeclBuilder,
               "#{__dir__}/builders/attribute_decl_builder"
      autoload :DeriveClauseBuilder, "#{__dir__}/builders/derive_clause_builder"
      autoload :DerivedAttrBuilder, "#{__dir__}/builders/derived_attr_builder"
      autoload :InverseClauseBuilder,
               "#{__dir__}/builders/inverse_clause_builder"
      autoload :InverseAttrBuilder, "#{__dir__}/builders/inverse_attr_builder"
      autoload :InverseAttrTypeBuilder,
               "#{__dir__}/builders/inverse_attr_type_builder"
      autoload :UniqueClauseBuilder, "#{__dir__}/builders/unique_clause_builder"
      autoload :UniqueRuleBuilder, "#{__dir__}/builders/unique_rule_builder"
      autoload :WhereClauseBuilder, "#{__dir__}/builders/where_clause_builder"
      autoload :DomainRuleBuilder, "#{__dir__}/builders/domain_rule_builder"
      autoload :ReferenceBuilder, "#{__dir__}/builders/reference_builder"
      autoload :LiteralBuilder, "#{__dir__}/builders/literal_builder"
      autoload :TypeDeclBuilder, "#{__dir__}/builders/type_decl_builder"
      autoload :TypeBuilder, "#{__dir__}/builders/type_builder"
      autoload :ExpressionBuilder, "#{__dir__}/builders/expression_builder"
      autoload :StatementBuilder, "#{__dir__}/builders/statement_builder"
      autoload :FunctionDeclBuilder, "#{__dir__}/builders/function_decl_builder"
      autoload :ProcedureDeclBuilder,
               "#{__dir__}/builders/procedure_decl_builder"
      autoload :RuleDeclBuilder, "#{__dir__}/builders/rule_decl_builder"
      autoload :SubtypeConstraintBuilder,
               "#{__dir__}/builders/subtype_constraint_builder"
      autoload :InterfaceBuilder, "#{__dir__}/builders/interface_builder"
      autoload :ConstantBuilder, "#{__dir__}/builders/constant_builder"
      autoload :QualifierBuilder, "#{__dir__}/builders/qualifier_builder"
      autoload :BuiltInBuilder, "#{__dir__}/builders/built_in_builder"
    end
  end
end
