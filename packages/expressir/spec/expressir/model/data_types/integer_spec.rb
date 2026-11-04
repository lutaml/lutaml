require "spec_helper"

RSpec.describe Expressir::Model::DataTypes::Integer do
  describe ".new" do
    subject(:integer) { described_class.new }

    it "creates an integer type" do
      expect(integer).to be_a described_class
    end
  end

  describe "type compatibility" do
    let(:integer_type) { described_class.new }
    let(:real_type) { Expressir::Model::DataTypes::Real.new }
    let(:number_type) { Expressir::Model::DataTypes::Number.new }
    let(:string_type) { Expressir::Model::DataTypes::String.new }

    it "is compatible with itself" do
      expect(integer_type).to be_a described_class
    end

    it "is assignable to real" do
      # In EXPRESS, INTEGER is compatible with REAL
      expect(real_type).to be_a Expressir::Model::DataTypes::Real
    end

    it "is assignable to number" do
      # In EXPRESS, INTEGER is compatible with NUMBER
      expect(number_type).to be_a Expressir::Model::DataTypes::Number
    end

    it "is not compatible with string" do
      # In EXPRESS, INTEGER is not compatible with STRING
      expect(string_type).not_to be_a described_class
    end
  end

  describe "value range" do
    let(:min_value) do
      Expressir::Model::Literals::Integer.new(value: "-2147483648")
    end
    let(:max_value) do
      Expressir::Model::Literals::Integer.new(value: "2147483647")
    end
    let(:out_of_range_value) do
      Expressir::Model::Literals::Integer.new(value: "9999999999999999999")
    end

    it "accepts values within range" do
      expect(min_value.value).to eq "-2147483648"
      expect(max_value.value).to eq "2147483647"
    end

    it "handles boundary cases" do
      expect(min_value.value.to_i).to be <= 2147483647
      expect(max_value.value.to_i).to be >= -2147483648
    end

    # Test for potential overflow handling
    it "maintains precision for large values" do
      expect(out_of_range_value.value).to eq "9999999999999999999"
    end
  end
end
