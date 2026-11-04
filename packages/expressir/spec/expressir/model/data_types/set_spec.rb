require "spec_helper"

RSpec.describe Expressir::Model::DataTypes::Set do
  describe ".new" do
    subject(:set) do
      described_class.new(
        bound1: bound1,
        bound2: bound2,
        base_type: base_type,
      )
    end

    let(:bound1) { Expressir::Model::Literals::Integer.new(value: "1") }
    let(:bound2) { Expressir::Model::Literals::Integer.new(value: "10") }
    let(:base_type) { Expressir::Model::DataTypes::String.new }

    it "creates a set type" do
      expect(set).to be_a described_class
      expect(set.bound1.value).to eq "1"
      expect(set.bound2.value).to eq "10"
      expect(set.base_type).to be_a Expressir::Model::DataTypes::String
    end
  end

  describe "set characteristics" do
    context "with different bounds" do
      let(:unbounded_set) do
        described_class.new(
          base_type: Expressir::Model::DataTypes::Integer.new,
        )
      end

      let(:zero_bound_set) do
        described_class.new(
          bound1: Expressir::Model::Literals::Integer.new(value: "0"),
          bound2: Expressir::Model::Literals::Integer.new(value: "0"),
          base_type: Expressir::Model::DataTypes::Integer.new,
        )
      end

      let(:single_element_set) do
        described_class.new(
          bound1: Expressir::Model::Literals::Integer.new(value: "1"),
          bound2: Expressir::Model::Literals::Integer.new(value: "1"),
          base_type: Expressir::Model::DataTypes::Integer.new,
        )
      end

      it "handles unbounded sets" do
        expect(unbounded_set.bound1).to be_nil
        expect(unbounded_set.bound2).to be_nil
      end

      it "handles zero-sized sets" do
        expect(zero_bound_set.bound1.value).to eq "0"
        expect(zero_bound_set.bound2.value).to eq "0"
      end

      it "handles single-element sets" do
        expect(single_element_set.bound1.value).to eq "1"
        expect(single_element_set.bound2.value).to eq "1"
      end
    end
  end

  describe "set operations" do
    let(:integer_set) do
      described_class.new(
        base_type: Expressir::Model::DataTypes::Integer.new,
      )
    end

    context "when initializing sets" do
      let(:empty_set) do
        Expressir::Model::Expressions::AggregateInitializer.new(items: [])
      end
      let(:single_item_set) do
        Expressir::Model::Expressions::AggregateInitializer.new(
          items: [Expressir::Model::Literals::Integer.new(value: "1")],
        )
      end

      it "handles empty set initialization" do
        expect(empty_set.items).to be_empty
      end

      it "handles single item initialization" do
        expect(single_item_set.items.length).to eq 1
        expect(single_item_set.items.first.value).to eq "1"
      end
    end
  end

  describe "edge cases" do
    context "with invalid bounds" do
      let(:reversed_bounds_set) do
        described_class.new(
          bound1: Expressir::Model::Literals::Integer.new(value: "10"),
          bound2: Expressir::Model::Literals::Integer.new(value: "1"),
          base_type: Expressir::Model::DataTypes::Integer.new,
        )
      end

      let(:negative_bounds_set) do
        described_class.new(
          bound1: Expressir::Model::Literals::Integer.new(value: "-5"),
          bound2: Expressir::Model::Literals::Integer.new(value: "-1"),
          base_type: Expressir::Model::DataTypes::Integer.new,
        )
      end

      it "handles reversed bounds" do
        expect(reversed_bounds_set.bound1.value).to eq "10"
        expect(reversed_bounds_set.bound2.value).to eq "1"
      end

      it "handles negative bounds" do
        expect(negative_bounds_set.bound1.value).to eq "-5"
        expect(negative_bounds_set.bound2.value).to eq "-1"
      end
    end

    context "with complex base types" do
      let(:set_of_sets) do
        described_class.new(
          base_type: described_class.new(
            base_type: Expressir::Model::DataTypes::Integer.new,
          ),
        )
      end

      let(:set_of_arrays) do
        described_class.new(
          base_type: Expressir::Model::DataTypes::Array.new(
            base_type: Expressir::Model::DataTypes::Integer.new,
          ),
        )
      end

      it "handles nested set types" do
        expect(set_of_sets.base_type).to be_a described_class
        expect(set_of_sets.base_type.base_type).to be_a Expressir::Model::DataTypes::Integer
      end

      it "handles sets of arrays" do
        expect(set_of_arrays.base_type).to be_a Expressir::Model::DataTypes::Array
        expect(set_of_arrays.base_type.base_type).to be_a Expressir::Model::DataTypes::Integer
      end
    end
  end
end
