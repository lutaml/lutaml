require "spec_helper"

RSpec.describe Expressir::Model::DataTypes::Binary do
  describe ".new" do
    subject(:binary) do
      described_class.new(
        width: width,
        fixed: fixed,
      )
    end

    let(:width) { Expressir::Model::Literals::Integer.new(value: "8") }
    let(:fixed) { true }

    it "creates a binary type" do
      expect(binary).to be_a described_class
      expect(binary.width.value).to eq "8"
      expect(binary.fixed).to be true
    end
  end

  describe "width characteristics" do
    context "with different width specifications" do
      let(:zero_width_binary) do
        described_class.new(
          width: Expressir::Model::Literals::Integer.new(value: "0"),
          fixed: true,
        )
      end

      let(:large_width_binary) do
        described_class.new(
          width: Expressir::Model::Literals::Integer.new(value: "32768"),
          fixed: true,
        )
      end

      let(:unbounded_binary) do
        described_class.new
      end

      it "handles zero width" do
        expect(zero_width_binary.width.value).to eq "0"
        expect(zero_width_binary.fixed).to be true
      end

      it "handles large width" do
        expect(large_width_binary.width.value).to eq "32768"
        expect(large_width_binary.fixed).to be true
      end

      it "handles unbounded width" do
        expect(unbounded_binary.width).to be_nil
        expect(unbounded_binary.fixed).to be_nil
      end
    end
  end

  describe "fixed vs variable width" do
    context "with different fixity settings" do
      let(:fixed_width_binary) do
        described_class.new(
          width: Expressir::Model::Literals::Integer.new(value: "8"),
          fixed: true,
        )
      end

      let(:variable_width_binary) do
        described_class.new(
          width: Expressir::Model::Literals::Integer.new(value: "8"),
          fixed: false,
        )
      end

      it "enforces fixed width" do
        expect(fixed_width_binary.width.value).to eq "8"
        expect(fixed_width_binary.fixed).to be true
      end

      it "allows variable width" do
        expect(variable_width_binary.width.value).to eq "8"
        expect(variable_width_binary.fixed).to be false
      end
    end
  end

  describe "edge cases" do
    context "with invalid width values" do
      let(:negative_width_binary) do
        described_class.new(
          width: Expressir::Model::Literals::Integer.new(value: "-8"),
          fixed: true,
        )
      end

      let(:max_width_binary) do
        described_class.new(
          width: Expressir::Model::Literals::Integer.new(value: "2147483647"),
          fixed: true,
        )
      end

      it "handles negative width" do
        expect(negative_width_binary.width.value).to eq "-8"
      end

      it "handles maximum width" do
        expect(max_width_binary.width.value).to eq "2147483647"
      end
    end

    context "with partial specifications" do
      let(:width_only_binary) do
        described_class.new(
          width: Expressir::Model::Literals::Integer.new(value: "8"),
        )
      end

      let(:fixed_only_binary) do
        described_class.new(
          fixed: true,
        )
      end

      it "handles width without fixed specification" do
        expect(width_only_binary.width.value).to eq "8"
        expect(width_only_binary.fixed).to be_nil
      end

      it "handles fixed without width specification" do
        expect(fixed_only_binary.width).to be_nil
        expect(fixed_only_binary.fixed).to be true
      end
    end
  end

  describe "type comparisons" do
    let(:binary1) do
      described_class.new(
        width: Expressir::Model::Literals::Integer.new(value: "8"),
        fixed: true,
      )
    end

    let(:binary2) do
      described_class.new(
        width: Expressir::Model::Literals::Integer.new(value: "8"),
        fixed: true,
      )
    end

    let(:different_binary) do
      described_class.new(
        width: Expressir::Model::Literals::Integer.new(value: "16"),
        fixed: false,
      )
    end

    it "identifies identical binary types" do
      expect(binary1.width.value).to eq binary2.width.value
      expect(binary1.fixed).to eq binary2.fixed
    end

    it "identifies different binary types" do
      expect(different_binary.width.value).not_to eq binary1.width.value
      expect(different_binary.fixed).not_to eq binary1.fixed
    end
  end
end
