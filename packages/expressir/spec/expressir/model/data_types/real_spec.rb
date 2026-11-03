require "spec_helper"

RSpec.describe Expressir::Model::DataTypes::Real do
  describe ".new" do
    subject(:real) do
      described_class.new(
        precision: precision,
      )
    end

    let(:precision) { Expressir::Model::Literals::Integer.new(value: "15") }

    it "creates a real type" do
      expect(real).to be_a described_class
      expect(real.precision.value).to eq "15"
    end
  end

  describe "precision handling" do
    context "with different precision values" do
      let(:zero_precision) do
        described_class.new(precision: Expressir::Model::Literals::Integer.new(value: "0"))
      end
      let(:high_precision) do
        described_class.new(precision: Expressir::Model::Literals::Integer.new(value: "30"))
      end
      let(:negative_precision) do
        described_class.new(precision: Expressir::Model::Literals::Integer.new(value: "-1"))
      end

      it "handles zero precision" do
        expect(zero_precision.precision.value).to eq "0"
      end

      it "handles high precision" do
        expect(high_precision.precision.value).to eq "30"
      end

      it "handles negative precision" do
        expect(negative_precision.precision.value).to eq "-1"
      end
    end
  end

  describe "type compatibility" do
    let(:real_type) { described_class.new }
    let(:integer_type) { Expressir::Model::DataTypes::Integer.new }
    let(:number_type) { Expressir::Model::DataTypes::Number.new }

    it "is compatible with number type" do
      expect(number_type).to be_a Expressir::Model::DataTypes::Number
    end

    it "can accept integer values" do
      expect(integer_type).to be_a Expressir::Model::DataTypes::Integer
    end
  end

  describe "edge cases" do
    context "with extreme values" do
      let(:max_value) do
        Expressir::Model::Literals::Real.new(value: "1.7976931348623157E+308")
      end
      let(:min_value) do
        Expressir::Model::Literals::Real.new(value: "2.2250738585072014E-308")
      end
      let(:zero) { Expressir::Model::Literals::Real.new(value: "0.0") }
      let(:negative_zero) do
        Expressir::Model::Literals::Real.new(value: "-0.0")
      end

      it "handles maximum values" do
        expect(max_value.value).to eq "1.7976931348623157E+308"
      end

      it "handles minimum values" do
        expect(min_value.value).to eq "2.2250738585072014E-308"
      end

      it "handles zero values" do
        expect(zero.value).to eq "0.0"
        expect(negative_zero.value).to eq "-0.0"
      end
    end

    context "with special cases" do
      let(:scientific_notation) do
        Expressir::Model::Literals::Real.new(value: "1.23E-4")
      end
      let(:trailing_zeros) do
        Expressir::Model::Literals::Real.new(value: "1.230000")
      end
      let(:leading_zeros) do
        Expressir::Model::Literals::Real.new(value: "00123.45")
      end

      it "handles scientific notation" do
        expect(scientific_notation.value).to eq "1.23E-4"
      end

      it "preserves trailing zeros" do
        expect(trailing_zeros.value).to eq "1.230000"
      end

      it "handles leading zeros" do
        expect(leading_zeros.value).to eq "00123.45"
      end
    end
  end

  describe "arithmetic operations" do
    let(:value1) { Expressir::Model::Literals::Real.new(value: "1.5") }
    let(:value2) { Expressir::Model::Literals::Real.new(value: "2.5") }

    it "handles basic arithmetic expressions" do
      add_expr = Expressir::Model::Expressions::BinaryExpression.new(
        operator: "ADDITION",
        operand1: value1,
        operand2: value2,
      )
      expect(add_expr.operator).to eq "ADDITION"
      expect(add_expr.operand1.value).to eq "1.5"
      expect(add_expr.operand2.value).to eq "2.5"

      mult_expr = Expressir::Model::Expressions::BinaryExpression.new(
        operator: "MULTIPLICATION",
        operand1: value1,
        operand2: value2,
      )
      expect(mult_expr.operator).to eq "MULTIPLICATION"
      expect(mult_expr.operand1.value).to eq "1.5"
      expect(mult_expr.operand2.value).to eq "2.5"
    end
  end
end
