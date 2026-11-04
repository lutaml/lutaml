require "spec_helper"

RSpec.describe Expressir::Model::Declarations::InterfaceItem do
  let(:simple_ref) do
    Expressir::Model::References::SimpleReference.new(id: "test_ref")
  end

  let(:interface_item) do
    described_class.new(
      ref: simple_ref,
      id: "renamed_item",
    )
  end

  describe ".new" do
    it "creates an interface item with required attributes" do
      expect(interface_item).to be_a described_class
      expect(interface_item.ref).to be_a Expressir::Model::References::SimpleReference
      expect(interface_item.id).to eq "renamed_item"
    end

    it "creates an interface item without id" do
      item = described_class.new(ref: simple_ref)
      expect(item.ref).to be_a Expressir::Model::References::SimpleReference
      expect(item.id).to be_nil
    end

    it "creates an interface item with nil values" do
      item = described_class.new
      expect(item.ref).to be_nil
      expect(item.id).to be_nil
    end
  end

  describe "attributes" do
    it "allows changing ref" do
      new_ref = Expressir::Model::References::SimpleReference.new(id: "new_ref")
      interface_item.ref = new_ref
      expect(interface_item.ref.id).to eq "new_ref"
    end

    it "allows changing id" do
      interface_item.id = "new_name"
      expect(interface_item.id).to eq "new_name"
    end
  end

  describe "inheritance" do
    it "inherits from ModelElement" do
      expect(interface_item).to be_a Expressir::Model::ModelElement
    end
  end

  describe "in schema context" do
    let(:schema) do
      Expressir::Model::Declarations::Schema.new(
        id: "test_schema",
        interfaces: [
          Expressir::Model::Declarations::Interface.new(
            kind: Expressir::Model::Declarations::Interface::USE,
            schema: Expressir::Model::References::SimpleReference.new(id: "source_schema"),
            items: [interface_item],
          ),
        ],
      )
    end

    it "is accessible through schema interfaces" do
      expect(schema.interfaces.first.items).to include(interface_item)
    end
  end
end
