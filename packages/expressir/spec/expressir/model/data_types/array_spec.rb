require "spec_helper"

RSpec.describe Expressir::Model::DataTypes::Array do
  describe ".new" do
    subject(:array) do
      described_class.new(
        bound1: bound1,
        bound2: bound2,
        optional: optional,
        unique: unique,
        base_type: base_type,
      )
    end

    let(:bound1) { Expressir::Model::Literals::Integer.new(value: "1") }
    let(:bound2) { Expressir::Model::Literals::Integer.new(value: "10") }
    let(:optional) { true }
    let(:unique) { true }
    let(:base_type) { Expressir::Model::DataTypes::String.new }

    it "creates an array type" do
      expect(array).to be_a described_class
      expect(array.bound1.value).to eq "1"
      expect(array.bound2.value).to eq "10"
      expect(array.optional).to be true
      expect(array.unique).to be true
      expect(array.base_type).to be_a Expressir::Model::DataTypes::String
    end
  end

  describe "array characteristics" do
    context "with different bounds" do
      let(:zero_size_array) do
        described_class.new(
          bound1: Expressir::Model::Literals::Integer.new(value: "1"),
          bound2: Expressir::Model::Literals::Integer.new(value: "0"),
          base_type: Expressir::Model::DataTypes::Integer.new,
        )
      end

      let(:equal_bounds_array) do
        described_class.new(
          bound1: Expressir::Model::Literals::Integer.new(value: "5"),
          bound2: Expressir::Model::Literals::Integer.new(value: "5"),
          base_type: Expressir::Model::DataTypes::Integer.new,
        )
      end

      let(:large_bounds_array) do
        described_class.new(
          bound1: Expressir::Model::Literals::Integer.new(value: "1"),
          bound2: Expressir::Model::Literals::Integer.new(value: "999999"),
          base_type: Expressir::Model::DataTypes::Integer.new,
        )
      end

      it "handles zero size arrays" do
        expect(zero_size_array.bound1.value).to eq "1"
        expect(zero_size_array.bound2.value).to eq "0"
      end

      it "handles fixed size arrays" do
        expect(equal_bounds_array.bound1.value).to eq "5"
        expect(equal_bounds_array.bound2.value).to eq "5"
      end

      it "handles large bounds" do
        expect(large_bounds_array.bound1.value).to eq "1"
        expect(large_bounds_array.bound2.value).to eq "999999"
      end
    end
  end

  describe "optional and unique combinations" do
    context "with different flag combinations" do
      let(:optional_unique_array) do
        described_class.new(
          optional: true,
          unique: true,
          base_type: Expressir::Model::DataTypes::String.new,
        )
      end

      let(:optional_nonunique_array) do
        described_class.new(
          optional: true,
          unique: false,
          base_type: Expressir::Model::DataTypes::String.new,
        )
      end

      let(:required_unique_array) do
        described_class.new(
          optional: false,
          unique: true,
          base_type: Expressir::Model::DataTypes::String.new,
        )
      end

      let(:required_nonunique_array) do
        described_class.new(
          optional: false,
          unique: false,
          base_type: Expressir::Model::DataTypes::String.new,
        )
      end

      it "handles optional unique arrays" do
        expect(optional_unique_array.optional).to be true
        expect(optional_unique_array.unique).to be true
      end

      it "handles optional non-unique arrays" do
        expect(optional_nonunique_array.optional).to be true
        expect(optional_nonunique_array.unique).to be false
      end

      it "handles required unique arrays" do
        expect(required_unique_array.optional).to be false
        expect(required_unique_array.unique).to be true
      end

      it "handles required non-unique arrays" do
        expect(required_nonunique_array.optional).to be false
        expect(required_nonunique_array.unique).to be false
      end
    end
  end

  describe "base type compatibility" do
    context "with different base types" do
      let(:integer_array) do
        described_class.new(
          base_type: Expressir::Model::DataTypes::Integer.new,
        )
      end

      let(:string_array) do
        described_class.new(
          base_type: Expressir::Model::DataTypes::String.new,
        )
      end

      let(:nested_array) do
        described_class.new(
          base_type: described_class.new(
            base_type: Expressir::Model::DataTypes::Integer.new,
          ),
        )
      end

      it "handles integer arrays" do
        expect(integer_array.base_type).to be_a Expressir::Model::DataTypes::Integer
      end

      it "handles string arrays" do
        expect(string_array.base_type).to be_a Expressir::Model::DataTypes::String
      end

      it "handles nested arrays" do
        expect(nested_array.base_type).to be_a described_class
        expect(nested_array.base_type.base_type).to be_a Expressir::Model::DataTypes::Integer
      end
    end
  end

  describe "edge cases" do
    context "with invalid bounds" do
      let(:negative_bounds_array) do
        described_class.new(
          bound1: Expressir::Model::Literals::Integer.new(value: "-5"),
          bound2: Expressir::Model::Literals::Integer.new(value: "-1"),
          base_type: Expressir::Model::DataTypes::Integer.new,
        )
      end

      let(:reversed_bounds_array) do
        described_class.new(
          bound1: Expressir::Model::Literals::Integer.new(value: "10"),
          bound2: Expressir::Model::Literals::Integer.new(value: "1"),
          base_type: Expressir::Model::DataTypes::Integer.new,
        )
      end

      it "handles negative bounds" do
        expect(negative_bounds_array.bound1.value).to eq "-5"
        expect(negative_bounds_array.bound2.value).to eq "-1"
      end

      it "handles reversed bounds" do
        expect(reversed_bounds_array.bound1.value).to eq "10"
        expect(reversed_bounds_array.bound2.value).to eq "1"
      end
    end

    context "with nil values" do
      let(:unbounded_array) do
        described_class.new(
          base_type: Expressir::Model::DataTypes::Integer.new,
        )
      end

      let(:no_base_type_array) do
        described_class.new(
          bound1: Expressir::Model::Literals::Integer.new(value: "1"),
          bound2: Expressir::Model::Literals::Integer.new(value: "10"),
        )
      end

      it "handles unbounded arrays" do
        expect(unbounded_array.bound1).to be_nil
        expect(unbounded_array.bound2).to be_nil
      end

      it "handles missing base type" do
        expect(no_base_type_array.base_type).to be_nil
      end
    end
  end
end
