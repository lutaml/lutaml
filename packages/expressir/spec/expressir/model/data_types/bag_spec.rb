require "spec_helper"

RSpec.describe Expressir::Model::DataTypes::Bag do
  describe ".new" do
    subject(:bag) do
      described_class.new(
        bound1: bound1,
        bound2: bound2,
        base_type: base_type,
      )
    end

    let(:bound1) { Expressir::Model::Literals::Integer.new(value: "1") }
    let(:bound2) { Expressir::Model::Literals::Integer.new(value: "10") }
    let(:base_type) { Expressir::Model::DataTypes::String.new }

    it "creates a bag type" do
      expect(bag).to be_a described_class
      expect(bag.bound1.value).to eq "1"
      expect(bag.bound2.value).to eq "10"
      expect(bag.base_type).to be_a Expressir::Model::DataTypes::String
    end
  end

  describe "bag characteristics" do
    context "with different bounds" do
      let(:unbounded_bag) do
        described_class.new(
          base_type: Expressir::Model::DataTypes::Integer.new,
        )
      end

      let(:single_element_bag) do
        described_class.new(
          bound1: Expressir::Model::Literals::Integer.new(value: "1"),
          bound2: Expressir::Model::Literals::Integer.new(value: "1"),
          base_type: Expressir::Model::DataTypes::Integer.new,
        )
      end

      let(:large_bounds_bag) do
        described_class.new(
          bound1: Expressir::Model::Literals::Integer.new(value: "1"),
          bound2: Expressir::Model::Literals::Integer.new(value: "999999"),
          base_type: Expressir::Model::DataTypes::Integer.new,
        )
      end

      it "handles unbounded bags" do
        expect(unbounded_bag.bound1).to be_nil
        expect(unbounded_bag.bound2).to be_nil
      end

      it "handles single element bags" do
        expect(single_element_bag.bound1.value).to eq "1"
        expect(single_element_bag.bound2.value).to eq "1"
      end

      it "handles large bounds" do
        expect(large_bounds_bag.bound1.value).to eq "1"
        expect(large_bounds_bag.bound2.value).to eq "999999"
      end
    end
  end

  describe "base type compatibility" do
    context "with different base types" do
      let(:integer_bag) do
        described_class.new(
          base_type: Expressir::Model::DataTypes::Integer.new,
        )
      end

      let(:nested_bag) do
        described_class.new(
          base_type: described_class.new(
            base_type: Expressir::Model::DataTypes::Integer.new,
          ),
        )
      end

      let(:array_bag) do
        described_class.new(
          base_type: Expressir::Model::DataTypes::Array.new(
            base_type: Expressir::Model::DataTypes::Integer.new,
          ),
        )
      end

      it "handles basic type elements" do
        expect(integer_bag.base_type).to be_a Expressir::Model::DataTypes::Integer
      end

      it "handles nested bags" do
        expect(nested_bag.base_type).to be_a described_class
        expect(nested_bag.base_type.base_type).to be_a Expressir::Model::DataTypes::Integer
      end

      it "handles array base types" do
        expect(array_bag.base_type).to be_a Expressir::Model::DataTypes::Array
        expect(array_bag.base_type.base_type).to be_a Expressir::Model::DataTypes::Integer
      end
    end
  end

  describe "edge cases" do
    context "with invalid bounds" do
      let(:zero_bounds_bag) do
        described_class.new(
          bound1: Expressir::Model::Literals::Integer.new(value: "0"),
          bound2: Expressir::Model::Literals::Integer.new(value: "0"),
          base_type: Expressir::Model::DataTypes::Integer.new,
        )
      end

      let(:negative_bounds_bag) do
        described_class.new(
          bound1: Expressir::Model::Literals::Integer.new(value: "-5"),
          bound2: Expressir::Model::Literals::Integer.new(value: "-1"),
          base_type: Expressir::Model::DataTypes::Integer.new,
        )
      end

      let(:reversed_bounds_bag) do
        described_class.new(
          bound1: Expressir::Model::Literals::Integer.new(value: "10"),
          bound2: Expressir::Model::Literals::Integer.new(value: "1"),
          base_type: Expressir::Model::DataTypes::Integer.new,
        )
      end

      it "handles zero bounds" do
        expect(zero_bounds_bag.bound1.value).to eq "0"
        expect(zero_bounds_bag.bound2.value).to eq "0"
      end

      it "handles negative bounds" do
        expect(negative_bounds_bag.bound1.value).to eq "-5"
        expect(negative_bounds_bag.bound2.value).to eq "-1"
      end

      it "handles reversed bounds" do
        expect(reversed_bounds_bag.bound1.value).to eq "10"
        expect(reversed_bounds_bag.bound2.value).to eq "1"
      end
    end

    context "with nil values" do
      let(:no_bounds_bag) do
        described_class.new(
          base_type: Expressir::Model::DataTypes::Integer.new,
        )
      end

      let(:partial_bounds_bag) do
        described_class.new(
          bound1: Expressir::Model::Literals::Integer.new(value: "1"),
          base_type: Expressir::Model::DataTypes::Integer.new,
        )
      end

      let(:no_base_type_bag) do
        described_class.new(
          bound1: Expressir::Model::Literals::Integer.new(value: "1"),
          bound2: Expressir::Model::Literals::Integer.new(value: "10"),
        )
      end

      it "handles missing bounds" do
        expect(no_bounds_bag.bound1).to be_nil
        expect(no_bounds_bag.bound2).to be_nil
      end

      it "handles partial bounds" do
        expect(partial_bounds_bag.bound1.value).to eq "1"
        expect(partial_bounds_bag.bound2).to be_nil
      end

      it "handles missing base type" do
        expect(no_base_type_bag.base_type).to be_nil
      end
    end
  end

  describe "type comparisons" do
    let(:bag1) do
      described_class.new(
        bound1: Expressir::Model::Literals::Integer.new(value: "1"),
        bound2: Expressir::Model::Literals::Integer.new(value: "10"),
        base_type: Expressir::Model::DataTypes::Integer.new,
      )
    end

    let(:bag2) do
      described_class.new(
        bound1: Expressir::Model::Literals::Integer.new(value: "1"),
        bound2: Expressir::Model::Literals::Integer.new(value: "10"),
        base_type: Expressir::Model::DataTypes::Integer.new,
      )
    end

    let(:different_bag) do
      described_class.new(
        bound1: Expressir::Model::Literals::Integer.new(value: "1"),
        bound2: Expressir::Model::Literals::Integer.new(value: "5"),
        base_type: Expressir::Model::DataTypes::String.new,
      )
    end

    it "identifies identical bags" do
      expect(bag1.bound1.value).to eq bag2.bound1.value
      expect(bag1.bound2.value).to eq bag2.bound2.value
      expect(bag1.base_type).to be_a Expressir::Model::DataTypes::Integer
      expect(bag2.base_type).to be_a Expressir::Model::DataTypes::Integer
    end

    it "identifies different bags" do
      expect(different_bag.bound2.value).not_to eq bag1.bound2.value
      expect(different_bag.base_type).not_to be_a Expressir::Model::DataTypes::Integer
    end
  end
end
