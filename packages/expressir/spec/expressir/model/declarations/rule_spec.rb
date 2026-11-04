require "spec_helper"

RSpec.describe Expressir::Model::Declarations::Rule do
  let(:type) do
    Expressir::Model::Declarations::Type.new(
      id: "test_type",
      underlying_type: Expressir::Model::DataTypes::String.new,
    )
  end

  let(:entity) do
    Expressir::Model::Declarations::Entity.new(
      id: "test_entity",
      attributes: [
        Expressir::Model::Declarations::Attribute.new(
          id: "test_attr",
          type: Expressir::Model::DataTypes::Integer.new,
        ),
      ],
    )
  end

  let(:subtype_constraint) do
    Expressir::Model::Declarations::SubtypeConstraint.new(
      id: "test_constraint",
      applies_to: Expressir::Model::References::SimpleReference.new(id: "test_entity"),
    )
  end

  let(:function) do
    Expressir::Model::Declarations::Function.new(
      id: "test_function",
      return_type: Expressir::Model::DataTypes::Integer.new,
    )
  end

  let(:procedure) do
    Expressir::Model::Declarations::Procedure.new(
      id: "test_procedure",
    )
  end

  let(:constant) do
    Expressir::Model::Declarations::Constant.new(
      id: "test_constant",
      type: Expressir::Model::DataTypes::Integer.new,
      expression: Expressir::Model::Literals::Integer.new(value: "42"),
    )
  end

  let(:variable) do
    Expressir::Model::Declarations::Variable.new(
      id: "test_var",
      type: Expressir::Model::DataTypes::Integer.new,
    )
  end

  let(:statement) do
    Expressir::Model::Statements::Assignment.new(
      ref: Expressir::Model::References::SimpleReference.new(id: "test_var"),
      expression: Expressir::Model::Literals::Integer.new(value: "1"),
    )
  end

  let(:where_rule) do
    Expressir::Model::Declarations::WhereRule.new(
      id: "test_where",
      expression: Expressir::Model::Expressions::BinaryExpression.new(
        operator: Expressir::Model::Expressions::BinaryExpression::GREATER_THAN,
        operand1: Expressir::Model::References::SimpleReference.new(id: "test_var"),
        operand2: Expressir::Model::Literals::Integer.new(value: "0"),
      ),
    )
  end

  let(:rule) do
    described_class.new(
      id: "test_rule",
      applies_to: [
        Expressir::Model::References::SimpleReference.new(id: "test_entity"),
      ],
      types: [type],
      entities: [entity],
      subtype_constraints: [subtype_constraint],
      functions: [function],
      procedures: [procedure],
      constants: [constant],
      variables: [variable],
      statements: [statement],
      where_rules: [where_rule],
      informal_propositions: [
        Expressir::Model::Declarations::RemarkItem.new(id: "IP1",
                                                       remarks: ["Informal proposition"]),
      ],
      remarks: ["Rule remark"],
      remark_items: [
        Expressir::Model::Declarations::RemarkItem.new(id: "remark1"),
      ],
    )
  end

  describe ".new" do
    it "creates a rule with all attributes" do
      expect(rule).to be_a described_class
      expect(rule.id).to eq "test_rule"
      expect(rule.applies_to).to contain_exactly(
        an_instance_of(Expressir::Model::References::SimpleReference),
      )
      expect(rule.applies_to.first.id).to eq "test_entity"
      expect(rule.types).to contain_exactly(type)
      expect(rule.entities).to contain_exactly(entity)
      expect(rule.subtype_constraints).to contain_exactly(subtype_constraint)
      expect(rule.functions).to contain_exactly(function)
      expect(rule.procedures).to contain_exactly(procedure)
      expect(rule.constants).to contain_exactly(constant)
      expect(rule.variables).to contain_exactly(variable)
      expect(rule.statements).to contain_exactly(statement)
      expect(rule.where_rules).to contain_exactly(where_rule)
      expect(rule.informal_propositions.size).to eq 1
      expect(rule.informal_propositions.first.id).to eq "IP1"
      expect(rule.informal_propositions.first.remarks).to eq ["Informal proposition"]
      expect(rule.remarks).to eq ["Rule remark"]
      expect(rule.remark_items.size).to eq 1
      expect(rule.remark_items.first.id).to eq "remark1"
    end

    it "creates a rule with minimal attributes" do
      rule = described_class.new(
        id: "minimal_rule",
        applies_to: [Expressir::Model::References::SimpleReference.new(id: "test_entity")],
      )
      expect(rule.id).to eq "minimal_rule"
      expect(rule.applies_to).to contain_exactly(
        an_instance_of(Expressir::Model::References::SimpleReference),
      )
      expect(rule.types).to eq([])
      expect(rule.entities).to eq([])
      expect(rule.subtype_constraints).to eq([])
      expect(rule.functions).to eq([])
      expect(rule.procedures).to eq([])
      expect(rule.constants).to eq([])
      expect(rule.variables).to eq([])
      expect(rule.statements).to eq([])
      expect(rule.where_rules).to eq([])
      expect(rule.informal_propositions).to eq([])
      expect(rule.remarks).to eq([])
      expect(rule.remark_items).to eq([])
    end
  end

  describe "inheritance" do
    it "inherits from ModelElement" do
      expect(rule).to be_a Expressir::Model::ModelElement
    end

    it "includes Identifier module" do
      expect(described_class.included_modules).to include(Expressir::Model::Identifier)
    end
  end

  describe "#children" do
    it "returns all child elements" do
      children = rule.children
      expect(children).to include(type)
      expect(children).to include(entity)
      expect(children).to include(subtype_constraint)
      expect(children).to include(function)
      expect(children).to include(procedure)
      expect(children).to include(constant)
      expect(children).to include(variable)
      expect(children).to include(where_rule)
      expect(children).to include(rule.informal_propositions.first)
      expect(children).to include(rule.remark_items.first)
    end

    it "includes enumeration items from types" do
      enum_type = Expressir::Model::Declarations::Type.new(
        id: "test_enum",
        underlying_type: Expressir::Model::DataTypes::Enumeration.new(
          items: [
            Expressir::Model::DataTypes::EnumerationItem.new(id: "ITEM1"),
            Expressir::Model::DataTypes::EnumerationItem.new(id: "ITEM2"),
          ],
        ),
      )
      rule.types = [enum_type]

      children = rule.children
      expect(children).to include(enum_type.underlying_type.items.first)
      expect(children).to include(enum_type.underlying_type.items.last)
    end
  end

  describe "parent-child relationships" do
    let(:schema) do
      Expressir::Model::Declarations::Schema.new(
        id: "test_schema",
        rules: [rule],
      )
    end

    before do
      schema # Force schema creation to establish parent relationship
    end

    it "establishes parent relationship with schema" do
      expect(rule.parent).to eq schema
    end

    it "establishes parent relationships with children" do
      expect(type.parent).to eq rule
      expect(entity.parent).to eq rule
      expect(subtype_constraint.parent).to eq rule
      expect(function.parent).to eq rule
      expect(procedure.parent).to eq rule
      expect(constant.parent).to eq rule
      expect(variable.parent).to eq rule
      expect(where_rule.parent).to eq rule
      expect(rule.informal_propositions.first.parent).to eq rule
      expect(rule.remark_items.first.parent).to eq rule
    end
  end

  describe "path resolution" do
    let(:schema) do
      Expressir::Model::Declarations::Schema.new(
        id: "test_schema",
        rules: [rule],
      )
    end

    before do
      schema.parent = Expressir::Model::Repository.new(schemas: [schema])
    end

    it "provides path for itself" do
      expect(rule.path).to eq "test_schema.test_rule"
    end

    it "provides path for children" do
      expect(type.path).to eq "test_schema.test_rule.test_type"
      expect(entity.path).to eq "test_schema.test_rule.test_entity"
      expect(function.path).to eq "test_schema.test_rule.test_function"
    end
  end
end
