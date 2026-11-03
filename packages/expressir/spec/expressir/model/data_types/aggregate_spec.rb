require "spec_helper"

RSpec.describe Expressir::Model::DataTypes::Aggregate do
  describe ".new" do
    subject(:aggregate) do
      described_class.new(
        id: id,
        base_type: base_type,
        remarks: remarks,
        remark_items: remark_items,
      )
    end

    let(:id) { "test_aggregate" }
    let(:base_type) { Expressir::Model::DataTypes::Boolean.new }
    let(:remarks) { ["First remark", "Second remark"] }
    let(:remark_items) do
      [
        Expressir::Model::Declarations::RemarkItem.new(id: "remark1"),
        Expressir::Model::Declarations::RemarkItem.new(id: "remark2"),
      ]
    end

    it "creates an aggregate type" do
      expect(aggregate).to be_a described_class
      expect(aggregate.id).to eq "test_aggregate"
      expect(aggregate.base_type).to be_a Expressir::Model::DataTypes::Boolean
      expect(aggregate.remarks).to eq ["First remark", "Second remark"]
    end

    context "with complex base types" do
      let(:nested_base_type) do
        described_class.new(
          id: "nested",
          base_type: Expressir::Model::DataTypes::Integer.new,
        )
      end

      it "handles nested aggregate types" do
        aggregate = described_class.new(
          id: "nested_aggregate",
          base_type: nested_base_type,
        )
        expect(aggregate.base_type).to be_a described_class
        expect(aggregate.base_type.base_type).to be_a Expressir::Model::DataTypes::Integer
      end
    end
  end

  describe "#children" do
    subject(:aggregate) do
      described_class.new(
        id: "test_aggregate",
        base_type: base_type,
        remark_items: remarks,
      )
    end

    let(:base_type) { Expressir::Model::DataTypes::Boolean.new }
    let(:remarks) do
      [
        Expressir::Model::Declarations::RemarkItem.new(id: "remark1"),
        Expressir::Model::Declarations::RemarkItem.new(id: "remark2"),
      ]
    end

    it "returns all remark items" do
      expect(aggregate.children).to contain_exactly(
        have_attributes(id: "remark1"),
        have_attributes(id: "remark2"),
      )
    end

    context "with no remarks" do
      let(:remarks) { nil }

      it "returns empty array" do
        expect(aggregate.children).to be_empty
      end
    end
  end

  describe "type compatibility" do
    let(:aggregate_type) { described_class.new(id: "test") }

    it "is not compatible with basic types" do
      expect(aggregate_type).not_to be_a Expressir::Model::DataTypes::Integer
      expect(aggregate_type).not_to be_a Expressir::Model::DataTypes::String
      expect(aggregate_type).not_to be_a Expressir::Model::DataTypes::Boolean
    end
  end

  describe "edge cases" do
    context "with circular references" do
      let(:type_a) { described_class.new(id: "type_a") }
      let(:type_b) { described_class.new(id: "type_b") }

      it "handles circular type references" do
        type_a.base_type = type_b
        type_b.base_type = type_a

        expect(type_a.base_type).to eq type_b
        expect(type_b.base_type).to eq type_a
      end
    end

    context "with nil values" do
      it "handles nil id" do
        aggregate = described_class.new(base_type: Expressir::Model::DataTypes::Boolean.new)
        expect(aggregate.id).to be_nil
      end

      it "handles nil base_type" do
        aggregate = described_class.new(id: "test")
        expect(aggregate.base_type).to be_nil
      end
    end
  end
end
