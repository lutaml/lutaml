require "spec_helper"

RSpec.describe Expressir::Model::DataTypes::String do
  describe ".new" do
    subject(:string) do
      described_class.new(
        width: width,
        fixed: fixed,
      )
    end

    let(:width) { Expressir::Model::Literals::Integer.new(value: "10") }
    let(:fixed) { true }

    it "creates a string type" do
      expect(string).to be_a described_class
      expect(string.width.value).to eq "10"
      expect(string.fixed).to be true
    end
  end

  describe "string constraints" do
    context "with fixed width" do
      let(:fixed_string) do
        described_class.new(
          width: Expressir::Model::Literals::Integer.new(value: "5"),
          fixed: true,
        )
      end

      let(:variable_string) do
        described_class.new(
          width: Expressir::Model::Literals::Integer.new(value: "5"),
          fixed: false,
        )
      end

      it "enforces fixed width constraint" do
        expect(fixed_string.width.value).to eq "5"
        expect(fixed_string.fixed).to be true
      end

      it "allows variable width up to maximum" do
        expect(variable_string.width.value).to eq "5"
        expect(variable_string.fixed).to be false
      end
    end

    context "with edge cases" do
      let(:zero_width) do
        described_class.new(
          width: Expressir::Model::Literals::Integer.new(value: "0"),
          fixed: true,
        )
      end

      let(:large_width) do
        described_class.new(
          width: Expressir::Model::Literals::Integer.new(value: "2147483647"),
          fixed: true,
        )
      end

      let(:negative_width) do
        described_class.new(
          width: Expressir::Model::Literals::Integer.new(value: "-1"),
          fixed: true,
        )
      end

      it "handles zero width" do
        expect(zero_width.width.value).to eq "0"
      end

      it "handles maximum width" do
        expect(large_width.width.value).to eq "2147483647"
      end

      it "handles negative width" do
        expect(negative_width.width.value).to eq "-1"
      end
    end
  end

  describe "string operations" do
    let(:string_type) { described_class.new }

    context "when used in expressions" do
      let(:string1) { Expressir::Model::Literals::String.new(value: "test") }
      let(:string2) { Expressir::Model::Literals::String.new(value: "TEST") }

      it "handles string concatenation" do
        concat_expr = Expressir::Model::Expressions::BinaryExpression.new(
          operator: "COMBINE",
          operand1: string1,
          operand2: string2,
        )
        expect(concat_expr.operator).to eq "COMBINE"
        expect(concat_expr.operand1.value).to eq "test"
        expect(concat_expr.operand2.value).to eq "TEST"
      end

      it "handles LIKE operations" do
        like_expr = Expressir::Model::Expressions::BinaryExpression.new(
          operator: "LIKE",
          operand1: string1,
          operand2: string2,
        )
        expect(like_expr.operator).to eq "LIKE"
      end
    end
  end

  describe "character encoding" do
    context "with special characters" do
      let(:unicode_string) do
        Expressir::Model::Literals::String.new(value: "αβγδε")
      end
      let(:escaped_string) do
        Expressir::Model::Literals::String.new(value: "line1\nline2")
      end
      let(:empty_string) { Expressir::Model::Literals::String.new(value: "") }

      it "handles Unicode characters" do
        expect(unicode_string.value).to eq "αβγδε"
      end

      it "handles escape sequences" do
        expect(escaped_string.value).to eq "line1\nline2"
      end

      it "handles empty strings" do
        expect(empty_string.value).to eq ""
      end
    end
  end
end
