require "spec_helper"

RSpec.describe Expressir::Model::Declarations::WhereRule do
  describe ".new" do
    subject(:where_rule) do
      described_class.new(
        id: id,
        expression: expression,
        remarks: remarks,
        remark_items: remark_items,
      )
    end

    let(:id) { "test_where_rule" }
    let(:expression) do
      Expressir::Model::Expressions::BinaryExpression.new(
        operator: "GREATER_THAN",
        operand1: Expressir::Model::References::SimpleReference.new(id: "SELF"),
        operand2: Expressir::Model::Literals::Integer.new(value: "0"),
      )
    end
    let(:remarks) { ["Test where rule remark"] }
    let(:remark_items) do
      [
        Expressir::Model::Declarations::RemarkItem.new(id: "remark1"),
      ]
    end

    it "creates a where rule" do
      expect(where_rule).to be_a described_class
      expect(where_rule.id).to eq "test_where_rule"
      expect(where_rule.expression).to be_a Expressir::Model::Expressions::BinaryExpression
      expect(where_rule.remarks).to eq ["Test where rule remark"]
      expect(where_rule.remark_items.first.id).to eq "remark1"
    end
  end

  describe "expression handling" do
    context "with different expression types" do
      let(:simple_comparison_rule) do
        described_class.new(
          id: "simple_rule",
          expression: Expressir::Model::Expressions::BinaryExpression.new(
            operator: "EQUAL",
            operand1: Expressir::Model::References::SimpleReference.new(id: "x"),
            operand2: Expressir::Model::Literals::Integer.new(value: "42"),
          ),
        )
      end

      let(:logical_expression_rule) do
        described_class.new(
          id: "logical_rule",
          expression: Expressir::Model::Expressions::BinaryExpression.new(
            operator: "AND",
            operand1: Expressir::Model::Literals::Logical.new(value: "TRUE"),
            operand2: Expressir::Model::Literals::Logical.new(value: "TRUE"),
          ),
        )
      end

      let(:function_call_rule) do
        described_class.new(
          id: "function_rule",
          expression: Expressir::Model::Expressions::FunctionCall.new(
            function: Expressir::Model::References::SimpleReference.new(id: "SIZEOF"),
            parameters: [
              Expressir::Model::References::SimpleReference.new(id: "items"),
            ],
          ),
        )
      end

      let(:complex_expression_rule) do
        described_class.new(
          id: "complex_rule",
          expression: Expressir::Model::Expressions::BinaryExpression.new(
            operator: "AND",
            operand1: Expressir::Model::Expressions::BinaryExpression.new(
              operator: "GREATER_THAN",
              operand1: Expressir::Model::References::SimpleReference.new(id: "x"),
              operand2: Expressir::Model::Literals::Integer.new(value: "0"),
            ),
            operand2: Expressir::Model::Expressions::BinaryExpression.new(
              operator: "LESS_THAN",
              operand1: Expressir::Model::References::SimpleReference.new(id: "x"),
              operand2: Expressir::Model::Literals::Integer.new(value: "100"),
            ),
          ),
        )
      end

      it "handles simple comparison expressions" do
        expect(simple_comparison_rule.expression.operator).to eq "EQUAL"
        expect(simple_comparison_rule.expression.operand1.id).to eq "x"
        expect(simple_comparison_rule.expression.operand2.value).to eq "42"
      end

      it "handles logical expressions" do
        expect(logical_expression_rule.expression.operator).to eq "AND"
        expect(logical_expression_rule.expression.operand1.value).to eq "TRUE"
        expect(logical_expression_rule.expression.operand2.value).to eq "TRUE"
      end

      it "handles function calls" do
        expect(function_call_rule.expression).to be_a Expressir::Model::Expressions::FunctionCall
        expect(function_call_rule.expression.function.id).to eq "SIZEOF"
        expect(function_call_rule.expression.parameters.first.id).to eq "items"
      end

      it "handles complex nested expressions" do
        expr = complex_expression_rule.expression
        expect(expr.operator).to eq "AND"
        expect(expr.operand1.operator).to eq "GREATER_THAN"
        expect(expr.operand2.operator).to eq "LESS_THAN"
      end
    end
  end

  describe "parent context" do
    context "with different parent types" do
      let(:entity_parent) do
        Expressir::Model::Declarations::Entity.new(
          id: "test_entity",
          where_rules: [
            described_class.new(
              id: "WR1",
              expression: Expressir::Model::Literals::Logical.new(value: "TRUE"),
            ),
          ],
        )
      end

      let(:type_parent) do
        Expressir::Model::Declarations::Type.new(
          id: "test_type",
          where_rules: [
            described_class.new(
              id: "WR1",
              expression: Expressir::Model::Literals::Logical.new(value: "TRUE"),
            ),
          ],
        )
      end

      it "handles entity parent" do
        rule = entity_parent.where_rules.first
        expect(rule.parent).to eq entity_parent
        expect(rule.id).to eq "WR1"
      end

      it "handles type parent" do
        rule = type_parent.where_rules.first
        expect(rule.parent).to eq type_parent
        expect(rule.id).to eq "WR1"
      end
    end
  end

  describe "edge cases" do
    context "with unusual configurations" do
      let(:empty_rule) do
        described_class.new(
          id: "empty_rule",
        )
      end

      let(:no_id_rule) do
        described_class.new(
          expression: Expressir::Model::Literals::Logical.new(value: "TRUE"),
        )
      end

      let(:complex_nested_expressions) do
        described_class.new(
          id: "nested_rule",
          expression: Expressir::Model::Expressions::BinaryExpression.new(
            operator: "AND",
            operand1: Expressir::Model::Expressions::BinaryExpression.new(
              operator: "OR",
              operand1: Expressir::Model::Literals::Logical.new(value: "TRUE"),
              operand2: Expressir::Model::Literals::Logical.new(value: "FALSE"),
            ),
            operand2: Expressir::Model::Expressions::UnaryExpression.new(
              operator: "NOT",
              operand: Expressir::Model::Literals::Logical.new(value: "FALSE"),
            ),
          ),
        )
      end

      it "handles empty rules" do
        expect(empty_rule.expression).to be_nil
      end

      it "handles missing id" do
        expect(no_id_rule.id).to be_nil
        expect(no_id_rule.expression.value).to eq "TRUE"
      end

      it "handles deeply nested expressions" do
        expr = complex_nested_expressions.expression
        expect(expr.operator).to eq "AND"
        expect(expr.operand1.operator).to eq "OR"
        expect(expr.operand2.operator).to eq "NOT"
      end
    end

    context "with naming patterns" do
      let(:empty_id_rule) do
        described_class.new(
          id: "",
          expression: Expressir::Model::Literals::Logical.new(value: "TRUE"),
        )
      end

      let(:long_id_rule) do
        described_class.new(
          id: "a" * 100,
          expression: Expressir::Model::Literals::Logical.new(value: "TRUE"),
        )
      end

      let(:special_chars_rule) do
        described_class.new(
          id: "rule_with_$pecial_chars",
          expression: Expressir::Model::Literals::Logical.new(value: "TRUE"),
        )
      end

      it "handles empty identifier" do
        expect(empty_id_rule.id).to eq ""
      end

      it "handles long identifier" do
        expect(long_id_rule.id.length).to eq 100
      end

      it "handles special characters in identifier" do
        expect(special_chars_rule.id).to eq "rule_with_$pecial_chars"
      end
    end
  end

  describe "#children" do
    let(:where_rule) do
      described_class.new(
        id: "test_rule",
        expression: Expressir::Model::Literals::Logical.new(value: "TRUE"),
        remark_items: [
          Expressir::Model::Declarations::RemarkItem.new(id: "remark1"),
          Expressir::Model::Declarations::RemarkItem.new(id: "remark2"),
        ],
      )
    end

    it "returns all remark items" do
      expect(where_rule.children).to contain_exactly(
        have_attributes(id: "remark1"),
        have_attributes(id: "remark2"),
      )
    end

    context "without remark items" do
      let(:simple_rule) do
        described_class.new(
          id: "simple_rule",
          expression: Expressir::Model::Literals::Logical.new(value: "TRUE"),
        )
      end

      it "returns empty array" do
        expect(simple_rule.children).to be_empty
      end
    end
  end
end
