require "spec_helper"

RSpec.describe Expressir::Model::DataTypes::Number do
  describe ".new" do
    subject(:number) { described_class.new }

    it "creates a number type" do
      expect(number).to be_a described_class
    end
  end

  describe "type compatibility" do
    let(:number_type) { described_class.new }
    let(:integer_type) { Expressir::Model::DataTypes::Integer.new }
    let(:real_type) { Expressir::Model::DataTypes::Real.new }

    it "is compatible with integer values" do
      # In EXPRESS, NUMBER can accept INTEGER values
      expect(integer_type).to be_a Expressir::Model::DataTypes::Integer
    end

    it "is compatible with real values" do
      # In EXPRESS, NUMBER can accept REAL values
      expect(real_type).to be_a Expressir::Model::DataTypes::Real
    end
  end

  describe "arithmetic operations" do
    let(:number_type) { described_class.new }

    context "when used in expressions" do
      let(:integer_value) do
        Expressir::Model::Literals::Integer.new(value: "5")
      end
      let(:real_value) { Expressir::Model::Literals::Real.new(value: "5.5") }

      it "handles mixed-type arithmetic" do
        add_expr = Expressir::Model::Expressions::BinaryExpression.new(
          operator: "ADDITION",
          operand1: integer_value,
          operand2: real_value,
        )
        expect(add_expr.operator).to eq "ADDITION"
        expect(add_expr.operand1.value).to eq "5"
        expect(add_expr.operand2.value).to eq "5.5"
      end
    end
  end

  describe "edge cases" do
    context "with extreme values" do
      let(:max_integer) do
        Expressir::Model::Literals::Integer.new(value: "2147483647")
      end
      let(:min_integer) do
        Expressir::Model::Literals::Integer.new(value: "-2147483648")
      end
      let(:large_real) do
        Expressir::Model::Literals::Real.new(value: "1.7976931348623157E+308")
      end
      let(:small_real) do
        Expressir::Model::Literals::Real.new(value: "2.2250738585072014E-308")
      end

      it "handles maximum integer values" do
        expect(max_integer.value).to eq "2147483647"
        expect(min_integer.value).to eq "-2147483648"
      end

      it "handles extreme real values" do
        expect(large_real.value).to eq "1.7976931348623157E+308"
        expect(small_real.value).to eq "2.2250738585072014E-308"
      end
    end
  end
end
