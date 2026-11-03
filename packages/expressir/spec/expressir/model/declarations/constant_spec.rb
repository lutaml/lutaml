require "spec_helper"

RSpec.describe Expressir::Model::Declarations::Constant do
  describe ".new" do
    subject(:constant) do
      described_class.new(
        id: id,
        type: type,
        expression: expression,
        remarks: remarks,
        remark_items: remark_items,
      )
    end

    let(:id) { "TEST_CONSTANT" }
    let(:type) { Expressir::Model::DataTypes::Integer.new }
    let(:expression) { Expressir::Model::Literals::Integer.new(value: "42") }
    let(:remarks) { ["Test constant remark"] }
    let(:remark_items) do
      [
        Expressir::Model::Declarations::RemarkItem.new(id: "remark1"),
      ]
    end

    it "creates a constant" do
      expect(constant).to be_a described_class
      expect(constant.id).to eq "TEST_CONSTANT"
      expect(constant.type).to be_a Expressir::Model::DataTypes::Integer
      expect(constant.expression.value).to eq "42"
      expect(constant.remarks).to eq ["Test constant remark"]
    end
  end

  describe "type compatibility" do
    context "with different type and expression combinations" do
      let(:integer_constant) do
        described_class.new(
          id: "INT_CONST",
          type: Expressir::Model::DataTypes::Integer.new,
          expression: Expressir::Model::Literals::Integer.new(value: "42"),
        )
      end

      let(:real_constant) do
        described_class.new(
          id: "REAL_CONST",
          type: Expressir::Model::DataTypes::Real.new,
          expression: Expressir::Model::Literals::Real.new(value: "3.14"),
        )
      end

      let(:string_constant) do
        described_class.new(
          id: "STR_CONST",
          type: Expressir::Model::DataTypes::String.new,
          expression: Expressir::Model::Literals::String.new(value: "test"),
        )
      end

      let(:logical_constant) do
        described_class.new(
          id: "BOOL_CONST",
          type: Expressir::Model::DataTypes::Logical.new,
          expression: Expressir::Model::Literals::Logical.new(value: "TRUE"),
        )
      end

      it "handles integer constants" do
        expect(integer_constant.type).to be_a Expressir::Model::DataTypes::Integer
        expect(integer_constant.expression.value).to eq "42"
      end

      it "handles real constants" do
        expect(real_constant.type).to be_a Expressir::Model::DataTypes::Real
        expect(real_constant.expression.value).to eq "3.14"
      end

      it "handles string constants" do
        expect(string_constant.type).to be_a Expressir::Model::DataTypes::String
        expect(string_constant.expression.value).to eq "test"
      end

      it "handles logical constants" do
        expect(logical_constant.type).to be_a Expressir::Model::DataTypes::Logical
        expect(logical_constant.expression.value).to eq "TRUE"
      end
    end
  end

  describe "complex expressions" do
    context "with different expression types" do
      let(:arithmetic_constant) do
        described_class.new(
          id: "CALC_CONST",
          type: Expressir::Model::DataTypes::Integer.new,
          expression: Expressir::Model::Expressions::BinaryExpression.new(
            operator: "ADDITION",
            operand1: Expressir::Model::Literals::Integer.new(value: "5"),
            operand2: Expressir::Model::Literals::Integer.new(value: "3"),
          ),
        )
      end

      let(:function_constant) do
        described_class.new(
          id: "FUNC_CONST",
          type: Expressir::Model::DataTypes::Integer.new,
          expression: Expressir::Model::Expressions::FunctionCall.new(
            function: Expressir::Model::References::SimpleReference.new(id: "ABS"),
            parameters: [Expressir::Model::Literals::Integer.new(value: "-42")],
          ),
        )
      end

      let(:reference_constant) do
        described_class.new(
          id: "REF_CONST",
          type: Expressir::Model::DataTypes::Integer.new,
          expression: Expressir::Model::References::SimpleReference.new(id: "OTHER_CONST"),
        )
      end

      it "handles arithmetic expressions" do
        expect(arithmetic_constant.expression).to be_a Expressir::Model::Expressions::BinaryExpression
        expect(arithmetic_constant.expression.operator).to eq "ADDITION"
        expect(arithmetic_constant.expression.operand1.value).to eq "5"
        expect(arithmetic_constant.expression.operand2.value).to eq "3"
      end

      it "handles function calls" do
        expect(function_constant.expression).to be_a Expressir::Model::Expressions::FunctionCall
        expect(function_constant.expression.function.id).to eq "ABS"
        expect(function_constant.expression.parameters.first.value).to eq "-42"
      end

      it "handles references" do
        expect(reference_constant.expression).to be_a Expressir::Model::References::SimpleReference
        expect(reference_constant.expression.id).to eq "OTHER_CONST"
      end
    end
  end

  describe "edge cases" do
    context "with invalid configurations" do
      let(:missing_type_constant) do
        described_class.new(
          id: "NO_TYPE",
          expression: Expressir::Model::Literals::Integer.new(value: "42"),
        )
      end

      let(:missing_expression_constant) do
        described_class.new(
          id: "NO_EXPR",
          type: Expressir::Model::DataTypes::Integer.new,
        )
      end

      let(:empty_id_constant) do
        described_class.new(
          id: "",
          type: Expressir::Model::DataTypes::Integer.new,
          expression: Expressir::Model::Literals::Integer.new(value: "42"),
        )
      end

      it "handles missing type" do
        expect(missing_type_constant.type).to be_nil
      end

      it "handles missing expression" do
        expect(missing_expression_constant.expression).to be_nil
      end

      it "handles empty identifier" do
        expect(empty_id_constant.id).to eq ""
      end
    end

    context "with unusual values" do
      let(:very_long_id_constant) do
        described_class.new(
          id: "CONST_#{'X' * 100}",
          type: Expressir::Model::DataTypes::String.new,
          expression: Expressir::Model::Literals::String.new(value: "test"),
        )
      end

      let(:special_chars_constant) do
        described_class.new(
          id: "CONST_$PECIAL",
          type: Expressir::Model::DataTypes::String.new,
          expression: Expressir::Model::Literals::String.new(value: "test"),
        )
      end

      let(:unicode_constant) do
        described_class.new(
          id: "CONST_UNICODE",
          type: Expressir::Model::DataTypes::String.new,
          expression: Expressir::Model::Literals::String.new(value: "αβγδε"),
        )
      end

      it "handles very long identifiers" do
        expect(very_long_id_constant.id.length).to be > 100
      end

      it "handles special characters in identifier" do
        expect(special_chars_constant.id).to eq "CONST_$PECIAL"
      end

      it "handles Unicode in expression" do
        expect(unicode_constant.expression.value).to eq "αβγδε"
      end
    end
  end

  describe "scope and visibility" do
    let(:parent_schema) do
      Expressir::Model::Declarations::Schema.new(
        id: "TEST_SCHEMA",
        constants: [
          described_class.new(
            id: "SCHEMA_CONST",
            type: Expressir::Model::DataTypes::Integer.new,
            expression: Expressir::Model::Literals::Integer.new(value: "42"),
          ),
        ],
      )
    end

    let(:parent_function) do
      Expressir::Model::Declarations::Function.new(
        id: "TEST_FUNCTION",
        constants: [
          described_class.new(
            id: "FUNCTION_CONST",
            type: Expressir::Model::DataTypes::Integer.new,
            expression: Expressir::Model::Literals::Integer.new(value: "42"),
          ),
        ],
      )
    end

    it "can be defined in schema scope" do
      expect(parent_schema.constants.first.id).to eq "SCHEMA_CONST"
      expect(parent_schema.constants.first.parent).to eq parent_schema
    end

    it "can be defined in function scope" do
      expect(parent_function.constants.first.id).to eq "FUNCTION_CONST"
      expect(parent_function.constants.first.parent).to eq parent_function
    end
  end

  describe "#children" do
    let(:constant) do
      described_class.new(
        id: "TEST_CONST",
        type: Expressir::Model::DataTypes::Integer.new,
        expression: Expressir::Model::Literals::Integer.new(value: "42"),
        remark_items: [
          Expressir::Model::Declarations::RemarkItem.new(id: "remark1"),
          Expressir::Model::Declarations::RemarkItem.new(id: "remark2"),
        ],
      )
    end

    it "returns remark items" do
      expect(constant.children).to contain_exactly(
        have_attributes(id: "remark1"),
        have_attributes(id: "remark2"),
      )
    end

    context "without remark items" do
      let(:constant_without_remarks) do
        described_class.new(
          id: "TEST_CONST",
          type: Expressir::Model::DataTypes::Integer.new,
          expression: Expressir::Model::Literals::Integer.new(value: "42"),
        )
      end

      it "returns empty array" do
        expect(constant_without_remarks.children).to be_empty
      end
    end
  end
end
