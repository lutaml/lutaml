require "spec_helper"

RSpec.describe Expressir::Model::DataTypes::Boolean do
  describe ".new" do
    subject(:boolean) { described_class.new }

    it "creates a boolean type" do
      expect(boolean).to be_a described_class
    end
  end

  describe "logical operations" do
    let(:boolean_type) { described_class.new }
    let(:logical_type) { Expressir::Model::DataTypes::Logical.new }

    it "is distinct from logical type" do
      expect(boolean_type).not_to be_a Expressir::Model::DataTypes::Logical
    end

    context "when used in expressions" do
      let(:true_value) do
        Expressir::Model::Literals::Logical.new(value: "TRUE")
      end
      let(:false_value) do
        Expressir::Model::Literals::Logical.new(value: "FALSE")
      end

      it "handles boolean operations" do
        # Test AND operation
        and_expr = Expressir::Model::Expressions::BinaryExpression.new(
          operator: "AND",
          operand1: true_value,
          operand2: false_value,
        )
        expect(and_expr.operator).to eq "AND"
        expect(and_expr.operand1.value).to eq "TRUE"
        expect(and_expr.operand2.value).to eq "FALSE"

        # Test OR operation
        or_expr = Expressir::Model::Expressions::BinaryExpression.new(
          operator: "OR",
          operand1: true_value,
          operand2: false_value,
        )
        expect(or_expr.operator).to eq "OR"
        expect(or_expr.operand1.value).to eq "TRUE"
        expect(or_expr.operand2.value).to eq "FALSE"

        # Test NOT operation
        not_expr = Expressir::Model::Expressions::UnaryExpression.new(
          operator: "NOT",
          operand: true_value,
        )
        expect(not_expr.operator).to eq "NOT"
        expect(not_expr.operand.value).to eq "TRUE"
      end
    end
  end

  describe "type compatibility" do
    let(:boolean_type) { described_class.new }

    it "is not compatible with numeric types" do
      expect(boolean_type).not_to be_a Expressir::Model::DataTypes::Number
      expect(boolean_type).not_to be_a Expressir::Model::DataTypes::Integer
      expect(boolean_type).not_to be_a Expressir::Model::DataTypes::Real
    end

    it "is not compatible with string type" do
      expect(boolean_type).not_to be_a Expressir::Model::DataTypes::String
    end
  end

  describe "edge cases" do
    let(:boolean_type) { described_class.new }

    context "when used in conditional expressions" do
      let(:true_value) do
        Expressir::Model::Literals::Logical.new(value: "TRUE")
      end

      it "can be used in if statements" do
        if_stmt = Expressir::Model::Statements::If.new(
          expression: true_value,
          statements: [],
          else_statements: [],
        )
        expect(if_stmt.expression.value).to eq "TRUE"
      end

      it "can be used in where rules" do
        where_rule = Expressir::Model::Declarations::WhereRule.new(
          id: "test_rule",
          expression: true_value,
        )
        expect(where_rule.expression.value).to eq "TRUE"
      end
    end
  end
end
