require "spec_helper"

RSpec.describe "Formatter architecture" do
  describe "format registry dispatch" do
    it "dispatches Schema to format_declarations_schema" do
      registry = Expressir::Express::Formatter.format_registry
      expect(registry[Expressir::Model::Declarations::Schema]).to eq(:format_declarations_schema)
    end

    it "dispatches all data types" do
      registry = Expressir::Express::Formatter.format_registry
      data_types = [
        Expressir::Model::DataTypes::Aggregate,
        Expressir::Model::DataTypes::Array,
        Expressir::Model::DataTypes::Bag,
        Expressir::Model::DataTypes::Binary,
        Expressir::Model::DataTypes::Boolean,
        Expressir::Model::DataTypes::Enumeration,
        Expressir::Model::DataTypes::EnumerationItem,
        Expressir::Model::DataTypes::Generic,
        Expressir::Model::DataTypes::GenericEntity,
        Expressir::Model::DataTypes::Integer,
        Expressir::Model::DataTypes::List,
        Expressir::Model::DataTypes::Logical,
        Expressir::Model::DataTypes::Number,
        Expressir::Model::DataTypes::Real,
        Expressir::Model::DataTypes::Select,
        Expressir::Model::DataTypes::Set,
        Expressir::Model::DataTypes::String,
      ]
      data_types.each do |dt|
        expect(registry).to have_key(dt),
                            "Missing registry entry for #{dt.name}"
      end
    end

    it "dispatches all statement types" do
      registry = Expressir::Express::Formatter.format_registry
      statements = [
        Expressir::Model::Statements::Alias,
        Expressir::Model::Statements::Assignment,
        Expressir::Model::Statements::Case,
        Expressir::Model::Statements::CaseAction,
        Expressir::Model::Statements::Compound,
        Expressir::Model::Statements::Escape,
        Expressir::Model::Statements::If,
        Expressir::Model::Statements::Null,
        Expressir::Model::Statements::ProcedureCall,
        Expressir::Model::Statements::Repeat,
        Expressir::Model::Statements::Return,
        Expressir::Model::Statements::Skip,
      ]
      statements.each do |st|
        expect(registry).to have_key(st),
                            "Missing registry entry for #{st.name}"
      end
    end

    it "dispatches all declaration types" do
      registry = Expressir::Express::Formatter.format_registry
      declarations = [
        Expressir::Model::Declarations::Attribute,
        Expressir::Model::Declarations::Constant,
        Expressir::Model::Declarations::Entity,
        Expressir::Model::Declarations::Function,
        Expressir::Model::Declarations::Interface,
        Expressir::Model::Declarations::InterfaceItem,
        Expressir::Model::Declarations::Parameter,
        Expressir::Model::Declarations::Procedure,
        Expressir::Model::Declarations::Rule,
        Expressir::Model::Declarations::Schema,
        Expressir::Model::Declarations::SchemaVersion,
        Expressir::Model::Declarations::SubtypeConstraint,
        Expressir::Model::Declarations::Type,
        Expressir::Model::Declarations::UniqueRule,
        Expressir::Model::Declarations::Variable,
        Expressir::Model::Declarations::WhereRule,
        Expressir::Model::Declarations::InformalPropositionRule,
      ]
      declarations.each do |dt|
        expect(registry).to have_key(dt),
                            "Missing registry entry for #{dt.name}"
      end
    end

    it "dispatches all expression types" do
      registry = Expressir::Express::Formatter.format_registry
      expressions = [
        Expressir::Model::Expressions::AggregateInitializer,
        Expressir::Model::Expressions::AggregateInitializerItem,
        Expressir::Model::Expressions::BinaryExpression,
        Expressir::Model::Expressions::EntityConstructor,
        Expressir::Model::Expressions::FunctionCall,
        Expressir::Model::Expressions::Interval,
        Expressir::Model::Expressions::QueryExpression,
        Expressir::Model::Expressions::UnaryExpression,
      ]
      expressions.each do |et|
        expect(registry).to have_key(et),
                            "Missing registry entry for #{et.name}"
      end
    end

    it "dispatches noop for unimplemented types" do
      registry = Expressir::Express::Formatter.format_registry
      expect(registry[Expressir::Model::Cache]).to eq(:format_noop)
      expect(registry[Expressir::Model::ModelElement]).to eq(:format_noop)
      expect(registry[Expressir::Model::Declarations::SchemaVersionItem]).to eq(:format_noop)
      expect(registry[Expressir::Model::Declarations::InterfacedItem]).to eq(:format_noop)
    end

    it "returns empty string for nil" do
      formatter = Expressir::Express::Formatter.new
      expect(formatter.format(nil)).to eq("")
    end
  end

  describe "HasRemarks concern" do
    it "is included in Identifier types" do
      schema = Expressir::Model::Declarations::Schema.new(id: "test")
      expect(schema).to be_a(Expressir::Model::HasRemarks)

      entity = Expressir::Model::Declarations::Entity.new(id: "e")
      expect(entity).to be_a(Expressir::Model::HasRemarks)
    end

    it "is included in RemarkItem" do
      item = Expressir::Model::Declarations::RemarkItem.new(id: "test")
      expect(item).to be_a(Expressir::Model::HasRemarks)
    end

    it "is included in InterfacedItem" do
      item = Expressir::Model::Declarations::InterfacedItem.new(id: "test")
      expect(item).to be_a(Expressir::Model::HasRemarks)
    end

    it "is not included in plain ModelElement" do
      element = Expressir::Model::Statements::Null.new
      expect(element).not_to be_a(Expressir::Model::HasRemarks)
    end
  end

  describe "mutation-free formatting" do
    it "does not mutate nil attributes to empty arrays" do
      unique_rule = Expressir::Model::Declarations::UniqueRule.new(id: "ur1")
      expect(unique_rule.attributes).to eq([])

      entity = Expressir::Model::Declarations::Entity.new(
        id: "e",
        unique_rules: [unique_rule],
      )
      unique_rule.parent = entity

      schema = Expressir::Model::Declarations::Schema.new(
        id: "s",
        entities: [entity],
      )
      entity.parent = schema

      formatter = Expressir::Express::Formatter.new
      formatter.format(schema)

      expect(unique_rule.attributes).to eq([])
    end

    it "does not mutate nil applies_to on rule" do
      rule = Expressir::Model::Declarations::Rule.new(id: "r", applies_to: [])
      entity_ref = Expressir::Model::References::SimpleReference.new(id: "e")
      rule.applies_to = [entity_ref]

      schema = Expressir::Model::Declarations::Schema.new(
        id: "s",
        entities: [Expressir::Model::Declarations::Entity.new(id: "e")],
        rules: [rule],
      )
      rule.parent = schema

      formatter = Expressir::Express::Formatter.new
      formatter.format(schema)

      expect(rule.applies_to.length).to eq(1)
    end

    it "does not mutate nil items on select" do
      select = Expressir::Model::DataTypes::Select.new(items: nil)
      type_decl = Expressir::Model::Declarations::Type.new(
        id: "t",
        underlying_type: select,
      )
      select.parent = type_decl

      schema = Expressir::Model::Declarations::Schema.new(
        id: "s",
        types: [type_decl],
      )
      type_decl.parent = schema

      formatter = Expressir::Express::Formatter.new
      formatter.format(schema)

      expect(select.items).to be_nil
    end

    it "does not mutate nil operands on ONEOF" do
      oneof = Expressir::Model::SupertypeExpressions::OneofSupertypeExpression.new(operands: nil)
      expect(oneof.operands).to be_nil

      formatter = Expressir::Express::Formatter.new
      result = formatter.format(oneof)

      expect(oneof.operands).to be_nil
      expect(result).to include("ONEOF")
    end
  end

  describe "PrettyFormatter DRY scope body" do
    it "formats function with locals and return" do
      repo = Expressir::Express::Parser.from_exp(
        "SCHEMA t; FUNCTION f : REAL; " \
        "LOCAL x : REAL; END_LOCAL; " \
        "RETURN (x); END_FUNCTION; END_SCHEMA;",
        use_native: false,
      )

      formatted = Expressir::Express::PrettyFormatter.new.format(repo)
      expect(formatted).to include("FUNCTION")
      expect(formatted).to include("LOCAL")
      expect(formatted).to include("END_FUNCTION")
    end

    it "formats rule with WHERE clause" do
      repo = Expressir::Express::Parser.from_exp(
        "SCHEMA t; ENTITY e; END_ENTITY; " \
        "RULE r FOR (e); WHERE wr1 : TRUE; END_RULE; END_SCHEMA;",
        use_native: false,
      )

      formatted = Expressir::Express::PrettyFormatter.new.format(repo)
      expect(formatted).to include("WHERE")
      expect(formatted).to include("END_RULE")
    end

    it "formats procedure with parameters" do
      repo = Expressir::Express::Parser.from_exp(
        "SCHEMA t; PROCEDURE p(x : INTEGER; VAR y : INTEGER); " \
        "y := x + 1; END_PROCEDURE; END_SCHEMA;",
        use_native: false,
      )

      formatted = Expressir::Express::PrettyFormatter.new.format(repo)
      expect(formatted).to include("PROCEDURE")
      expect(formatted).to include("VAR")
      expect(formatted).to include("END_PROCEDURE")
    end
  end

  describe "binary literal % prefix" do
    it "outputs % prefix per ISO 10303-11 rule 139" do
      repo = Expressir::Express::Parser.from_exp(
        "SCHEMA t; FUNCTION f : BOOLEAN; LOCAL x : BINARY; END_LOCAL; " \
        "x := %01010101; RETURN (TRUE); END_FUNCTION; END_SCHEMA;",
        use_native: false,
      )

      formatted = Expressir::Express::Formatter.format(repo)
      expect(formatted).to include("%01010101")
    end
  end

  describe "Liquid drop memoization" do
    it "memoizes full_source on Schema" do
      schema = Expressir::Model::Declarations::Schema.new(id: "test")
      repo = Expressir::Model::Repository.new
      schema.parent = repo

      result1 = schema.full_source
      result2 = schema.full_source
      expect(result1).to equal(result2)
    end

    it "memoizes source on Schema" do
      schema = Expressir::Model::Declarations::Schema.new(id: "test")
      repo = Expressir::Model::Repository.new
      schema.parent = repo

      result1 = schema.source
      result2 = schema.source
      expect(result1).to equal(result2)
    end

    it "memoizes formatted on Schema" do
      schema = Expressir::Model::Declarations::Schema.new(id: "test")
      repo = Expressir::Model::Repository.new
      schema.parent = repo

      result1 = schema.formatted
      result2 = schema.formatted
      expect(result1).to equal(result2)
    end
  end
end
