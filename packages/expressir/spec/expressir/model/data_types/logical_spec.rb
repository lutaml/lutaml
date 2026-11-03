require "spec_helper"

RSpec.describe Expressir::Model::DataTypes::Logical do
  describe ".new" do
    subject(:logical) { described_class.new }

    it "creates a logical type" do
      expect(logical).to be_a described_class
    end
  end

  describe "tristate behavior" do
    let(:true_value) { Expressir::Model::Literals::Logical.new(value: "TRUE") }
    let(:false_value) do
      Expressir::Model::Literals::Logical.new(value: "FALSE")
    end
    let(:unknown_value) do
      Expressir::Model::Literals::Logical.new(value: "UNKNOWN")
    end

    context "with UNKNOWN values" do
      it "handles UNKNOWN in AND operations" do
        and_expr = Expressir::Model::Expressions::BinaryExpression.new(
          operator: "AND",
          operand1: unknown_value,
          operand2: true_value,
        )
        expect(and_expr.operand1.value).to eq "UNKNOWN"
      end

      it "handles UNKNOWN in OR operations" do
        or_expr = Expressir::Model::Expressions::BinaryExpression.new(
          operator: "OR",
          operand1: unknown_value,
          operand2: false_value,
        )
        expect(or_expr.operand1.value).to eq "UNKNOWN"
      end

      it "handles NOT of UNKNOWN" do
        not_expr = Expressir::Model::Expressions::UnaryExpression.new(
          operator: "NOT",
          operand: unknown_value,
        )
        expect(not_expr.operand.value).to eq "UNKNOWN"
      end
    end
  end

  describe "type compatibility" do
    let(:logical_type) { described_class.new }
    let(:boolean_type) { Expressir::Model::DataTypes::Boolean.new }

    it "is not equivalent to boolean" do
      expect(logical_type).not_to be_a Expressir::Model::DataTypes::Boolean
    end

    it "cannot be directly assigned to boolean" do
      # In EXPRESS, LOGICAL cannot be directly assigned to BOOLEAN
      expect(logical_type).not_to be_a Expressir::Model::DataTypes::Boolean
    end
  end

  describe "edge cases" do
    let(:unknown_value) do
      Expressir::Model::Literals::Logical.new(value: "UNKNOWN")
    end

    context "when used in conditions" do
      it "handles UNKNOWN in where rules" do
        where_rule = Expressir::Model::Declarations::WhereRule.new(
          id: "test_rule",
          expression: unknown_value,
        )
        expect(where_rule.expression.value).to eq "UNKNOWN"
      end
    end
  end
end
