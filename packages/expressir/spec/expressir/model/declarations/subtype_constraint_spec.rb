require "spec_helper"

RSpec.describe Expressir::Model::Declarations::SubtypeConstraint do
  let(:entity_ref) do
    Expressir::Model::References::SimpleReference.new(id: "base_entity")
  end

  let(:total_over_refs) do
    [
      Expressir::Model::References::SimpleReference.new(id: "entity1"),
      Expressir::Model::References::SimpleReference.new(id: "entity2"),
    ]
  end

  let(:supertype_expression) do
    Expressir::Model::SupertypeExpressions::OneofSupertypeExpression.new(
      operands: [
        Expressir::Model::References::SimpleReference.new(id: "entity3"),
        Expressir::Model::References::SimpleReference.new(id: "entity4"),
      ],
    )
  end

  let(:subtype_constraint) do
    described_class.new(
      id: "test_constraint",
      applies_to: entity_ref,
      abstract: true,
      total_over: total_over_refs,
      supertype_expression: supertype_expression,
      remarks: ["First remark", "Second remark"],
      remark_items: [
        Expressir::Model::Declarations::RemarkItem.new(id: "remark1"),
        Expressir::Model::Declarations::RemarkItem.new(id: "remark2"),
      ],
    )
  end

  describe ".new" do
    it "creates a subtype constraint with all attributes" do
      expect(subtype_constraint).to be_a described_class
      expect(subtype_constraint.id).to eq "test_constraint"
      expect(subtype_constraint.applies_to).to be_a Expressir::Model::References::SimpleReference
      expect(subtype_constraint.applies_to.id).to eq "base_entity"
      expect(subtype_constraint.abstract).to be true
      expect(subtype_constraint.total_over.size).to eq 2
      expect(subtype_constraint.total_over.first.id).to eq "entity1"
      expect(subtype_constraint.total_over.last.id).to eq "entity2"
      expect(subtype_constraint.supertype_expression).to be_a Expressir::Model::SupertypeExpressions::OneofSupertypeExpression
      expect(subtype_constraint.remarks).to eq ["First remark", "Second remark"]
      expect(subtype_constraint.remark_items.size).to eq 2
    end

    it "creates a subtype constraint with minimal attributes" do
      constraint = described_class.new(
        id: "test_constraint",
        applies_to: entity_ref,
      )
      expect(constraint.id).to eq "test_constraint"
      expect(constraint.applies_to).to be_a Expressir::Model::References::SimpleReference
      expect(constraint.abstract).to be_nil
      expect(constraint.total_over).to eq([])
      expect(constraint.supertype_expression).to be_nil
      expect(constraint.remarks).to eq([])
      expect(constraint.remark_items).to eq([])
    end
  end

  describe "parse path" do
    it "populates total_over from TOTAL_OVER (entity_ref list)" do
      src = <<~EXP
        SCHEMA root;
        ENTITY person; name : STRING; END_ENTITY;
        ENTITY employee SUBTYPE OF (person); staff_no : STRING; END_ENTITY;
        SUBTYPE_CONSTRAINT person_sc FOR person;
          TOTAL_OVER (person, employee);
        END_SUBTYPE_CONSTRAINT;
        END_SCHEMA;
      EXP
      file = Expressir::Express::Parser.from_exp(src, skip_references: true)
      sc = file.schemas.first.subtype_constraints.first
      expect(sc.total_over.map(&:id)).to eq(%w[person employee])
    end
  end

  describe "inheritance" do
    it "inherits from ModelElement" do
      expect(subtype_constraint).to be_a Expressir::Model::ModelElement
    end

    it "includes Identifier module" do
      expect(described_class.included_modules).to include(Expressir::Model::Identifier)
    end
  end

  describe "#children" do
    it "returns remark items" do
      expect(subtype_constraint.children).to match_array(subtype_constraint.remark_items)
    end

    it "returns empty array when no remark items" do
      constraint = described_class.new(
        id: "test_constraint",
        applies_to: entity_ref,
      )
      expect(constraint.children).to be_empty
    end
  end

  describe "in schema context" do
    let(:schema) do
      Expressir::Model::Declarations::Schema.new(
        id: "test_schema",
        subtype_constraints: [subtype_constraint],
      )
    end

    it "can be used in schemas" do
      expect(schema.subtype_constraints).to include(subtype_constraint)
    end

    it "sets parent relationship" do
      expect(schema.subtype_constraints.first.parent).to eq schema
    end
  end

  describe "with different supertype expressions" do
    let(:binary_supertype_expression) do
      Expressir::Model::SupertypeExpressions::BinarySupertypeExpression.new(
        operator: "AND",
        operand1: Expressir::Model::References::SimpleReference.new(id: "entity1"),
        operand2: Expressir::Model::References::SimpleReference.new(id: "entity2"),
      )
    end

    it "supports binary supertype expressions" do
      constraint = described_class.new(
        id: "test_constraint",
        applies_to: entity_ref,
        supertype_expression: binary_supertype_expression,
      )
      expect(constraint.supertype_expression).to be_a Expressir::Model::SupertypeExpressions::BinarySupertypeExpression
      expect(constraint.supertype_expression.operator).to eq "AND"
    end

    it "supports oneof supertype expressions" do
      constraint = described_class.new(
        id: "test_constraint",
        applies_to: entity_ref,
        supertype_expression: supertype_expression,
      )
      expect(constraint.supertype_expression).to be_a Expressir::Model::SupertypeExpressions::OneofSupertypeExpression
      expect(constraint.supertype_expression.operands.size).to eq 2
    end
  end

  describe "in function/procedure context" do
    let(:function) do
      Expressir::Model::Declarations::Function.new(
        id: "test_function",
        subtype_constraints: [subtype_constraint],
      )
    end

    let(:procedure) do
      Expressir::Model::Declarations::Procedure.new(
        id: "test_procedure",
        subtype_constraints: [subtype_constraint],
      )
    end

    it "can be used in functions" do
      expect(function.subtype_constraints).to include(subtype_constraint)
    end

    it "can be used in procedures" do
      expect(procedure.subtype_constraints).to include(subtype_constraint)
    end

    it "sets parent relationship" do
      expect(function.subtype_constraints.first.parent).to eq function
      expect(procedure.subtype_constraints.first.parent).to eq procedure
    end
  end
end
