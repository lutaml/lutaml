require "spec_helper"

RSpec.describe Expressir::Model::Declarations::RemarkItem do
  let(:remark_item) do
    described_class.new(
      id: "remark1",
      remarks: ["First remark", "Second remark"],
    )
  end

  let(:parent_entity) do
    Expressir::Model::Declarations::Entity.new(
      id: "test_entity",
      remark_items: [remark_item],
    )
  end

  describe ".new" do
    it "creates a remark item with all attributes" do
      expect(remark_item).to be_a described_class
      expect(remark_item.id).to eq "remark1"
      expect(remark_item.remarks).to eq ["First remark", "Second remark"]
    end

    it "creates a remark item with only id" do
      item = described_class.new(id: "remark1")
      expect(item.id).to eq "remark1"
      expect(item.remarks).to eq([])
    end

    it "creates a remark item with minimal attributes" do
      item = described_class.new
      expect(item.id).to be_nil
      expect(item.remarks).to eq([])
    end
  end

  describe "inheritance" do
    it "inherits from ModelElement" do
      expect(remark_item).to be_a Expressir::Model::ModelElement
    end
  end

  describe "in entity context" do
    it "attaches to entity as remark item" do
      expect(parent_entity.remark_items).to include(remark_item)
      expect(remark_item.parent).to eq parent_entity
    end
  end

  describe "in informal proposition context" do
    let(:informal_proposition) do
      described_class.new(
        id: "IP1",
        remarks: ["Informal proposition"],
      )
    end

    let(:parent_rule) do
      Expressir::Model::Declarations::Rule.new(
        id: "test_rule",
        applies_to: [Expressir::Model::References::SimpleReference.new(id: "test_entity")],
        informal_propositions: [informal_proposition],
      )
    end

    it "attaches to rule as informal proposition" do
      expect(parent_rule.informal_propositions).to include(informal_proposition)
      expect(informal_proposition.parent).to eq parent_rule
    end

    it "is identified as informal proposition by IP prefix" do
      expect(informal_proposition.id).to match(/^IP\d+$/)
    end
  end

  describe "in type context" do
    let(:parent_type) do
      Expressir::Model::Declarations::Type.new(
        id: "test_type",
        underlying_type: Expressir::Model::DataTypes::String.new,
        remark_items: [remark_item],
      )
    end

    it "attaches to type as remark item" do
      expect(parent_type.remark_items).to include(remark_item)
      expect(remark_item.parent).to eq parent_type
    end
  end

  describe "in schema context" do
    let(:parent_schema) do
      Expressir::Model::Declarations::Schema.new(
        id: "test_schema",
        remark_items: [remark_item],
      )
    end

    it "attaches to schema as remark item" do
      expect(parent_schema.remark_items).to include(remark_item)
      expect(remark_item.parent).to eq parent_schema
    end
  end

  describe "path resolution" do
    let(:schema) do
      Expressir::Model::Declarations::Schema.new(
        id: "test_schema",
        entities: [parent_entity],
      )
    end

    let(:repository) do
      Expressir::Model::Repository.new(schemas: [schema])
    end

    before do
      schema.parent = repository
    end

    it "provides correct path through parent hierarchy" do
      expect(remark_item.path).to eq "test_schema.test_entity.remark1"
    end
  end

  describe "remarks handling" do
    it "supports multiple remarks" do
      item = described_class.new(
        id: "multi_remark",
        remarks: ["First", "Second", "Third"],
      )
      expect(item.remarks.size).to eq 3
      expect(item.remarks).to eq ["First", "Second", "Third"]
    end

    it "supports empty remarks array" do
      item = described_class.new(id: "no_remarks")
      expect(item.remarks).to eq([])
    end

    it "supports remarks with special characters" do
      item = described_class.new(
        id: "special_chars",
        remarks: ["Remark with spaces", "Remark with\nnewline",
                  "Remark with \"quotes\""],
      )
      expect(item.remarks.size).to eq 3
      expect(item.remarks).to include("Remark with spaces")
      expect(item.remarks).to include("Remark with\nnewline")
      expect(item.remarks).to include("Remark with \"quotes\"")
    end
  end

  describe "formatting" do
    let(:schema) do
      Expressir::Model::Declarations::Schema.new(
        id: "test_schema",
        entities: [parent_entity],
      )
    end

    let(:repository) do
      Expressir::Model::Repository.new(schemas: [schema])
    end

    before do
      schema.parent = repository
    end

    it "formats as single-line remark" do
      expect(remark_item.to_s).to include('--"test_schema.test_entity.remark1"')
    end

    it "formats as multi-line remark when remarks contain newlines" do
      item = described_class.new(
        id: "multiline",
        remarks: ["First line\nSecond line"],
      )
      formatted = item.to_s
      expect(formatted).to include('(*"')
      expect(formatted).to include("*)")
    end
  end
end
