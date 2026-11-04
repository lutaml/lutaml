# frozen_string_literal: true

require "spec_helper"

RSpec.describe Expressir::Model::Indexes::ReferenceIndex do
  # Use REAL objects instead of mocks
  let(:use_interface) do
    Expressir::Model::Declarations::Interface.new(
      kind: Expressir::Model::Declarations::Interface::USE,
      schema: Expressir::Model::Declarations::Schema.new(id: "referenced_schema"),
      items: [
        Expressir::Model::Declarations::InterfaceItem.new(
          ref: Expressir::Model::References::SimpleReference.new(id: "entity1"),
        ),
        Expressir::Model::Declarations::InterfaceItem.new(
          ref: Expressir::Model::References::SimpleReference.new(id: "type1"),
        ),
      ],
    )
  end

  let(:reference_interface) do
    Expressir::Model::Declarations::Interface.new(
      kind: Expressir::Model::Declarations::Interface::REFERENCE,
      schema: Expressir::Model::Declarations::Schema.new(id: "other_schema"),
      items: [
        Expressir::Model::Declarations::InterfaceItem.new(
          ref: Expressir::Model::References::SimpleReference.new(id: "entity2"),
        ),
      ],
    )
  end

  let(:circular_interface1) do
    Expressir::Model::Declarations::Interface.new(
      kind: Expressir::Model::Declarations::Interface::USE,
      schema: Expressir::Model::Declarations::Schema.new(id: "schema2"),
      items: [],
    )
  end

  let(:circular_interface2) do
    Expressir::Model::Declarations::Interface.new(
      kind: Expressir::Model::Declarations::Interface::USE,
      schema: Expressir::Model::Declarations::Schema.new(id: "schema3"),
      items: [],
    )
  end

  let(:circular_interface3) do
    Expressir::Model::Declarations::Interface.new(
      kind: Expressir::Model::Declarations::Interface::USE,
      schema: Expressir::Model::Declarations::Schema.new(id: "schema1"),
      items: [],
    )
  end

  let(:schema1) do
    Expressir::Model::Declarations::Schema.new(
      id: "schema1",
      interfaces: [use_interface, reference_interface],
    )
  end

  let(:schema2) do
    Expressir::Model::Declarations::Schema.new(
      id: "schema2",
      interfaces: [],
    )
  end

  let(:schema3) do
    Expressir::Model::Declarations::Schema.new(
      id: "schema3",
      interfaces: [],
    )
  end

  describe "#initialize" do
    it "creates an empty index when no schemas provided" do
      index = described_class.new

      expect(index.use_from).to be_a(Hash)
      expect(index.reference_from).to be_a(Hash)
      expect(index.dependencies).to be_a(Hash)
    end

    it "builds indexes when schemas provided" do
      index = described_class.new([schema1])

      expect(index.use_from["schema1"]).not_to be_empty
      expect(index.dependencies["schema1"]).not_to be_empty
    end

    it "handles empty array" do
      index = described_class.new([])

      expect(index.use_from).to be_a(Hash)
      expect(index.dependencies).to be_a(Hash)
    end
  end

  describe "#build" do
    let(:index) { described_class.new }

    it "builds USE FROM references" do
      index.build([schema1])

      use_refs = index.use_from["schema1"]
      expect(use_refs).not_to be_empty
      expect(use_refs.first[:schema]).to eq("referenced_schema")
      expect(use_refs.first[:items]).to contain_exactly("entity1", "type1")
    end

    it "builds REFERENCE FROM references" do
      index.build([schema1])

      ref_refs = index.reference_from["schema1"]
      expect(ref_refs).not_to be_empty
      expect(ref_refs.first[:schema]).to eq("other_schema")
      expect(ref_refs.first[:items]).to contain_exactly("entity2")
    end

    it "builds dependency graph" do
      index.build([schema1])

      deps = index.dependencies["schema1"]
      expect(deps).to include("referenced_schema", "other_schema")
    end

    it "handles schemas with nil interfaces" do
      schema_no_interfaces = Expressir::Model::Declarations::Schema.new(
        id: "empty_schema",
        interfaces: nil,
      )

      expect { index.build([schema_no_interfaces]) }.not_to raise_error
    end

    it "handles empty interfaces collection" do
      schema_empty_interfaces = Expressir::Model::Declarations::Schema.new(
        id: "empty_schema",
        interfaces: [],
      )

      index.build([schema_empty_interfaces])

      expect(index.use_from["empty_schema"]).to eq([])
      expect(index.reference_from["empty_schema"]).to eq([])
    end

    it "clears previous indexes on rebuild" do
      index.build([schema1])
      initial_deps = index.dependencies["schema1"].dup

      index.build([schema2])

      expect(index.dependencies["schema1"]).not_to eq(initial_deps)
    end

    it "handles multiple interfaces in same schema" do
      multi_interface_schema = Expressir::Model::Declarations::Schema.new(
        id: "multi",
        interfaces: [use_interface, reference_interface],
      )

      index.build([multi_interface_schema])

      expect(index.use_from["multi"].size).to eq(1)
      expect(index.reference_from["multi"].size).to eq(1)
    end
  end

  describe "#use_references" do
    let(:index) { described_class.new([schema1]) }

    it "returns USE FROM references for a schema" do
      result = index.use_references("schema1")

      expect(result).to be_an(Array)
      expect(result.first[:schema]).to eq("referenced_schema")
    end

    it "returns empty array for schema without USE FROM" do
      result = index.use_references("schema2")

      expect(result).to eq([])
    end

    it "handles case-insensitive schema names" do
      result = index.use_references("SCHEMA1")

      expect(result).to be_an(Array)
      expect(result).not_to be_empty
    end

    it "returns empty array for non-existent schema" do
      result = index.use_references("nonexistent")

      expect(result).to eq([])
    end
  end

  describe "#reference_references" do
    let(:index) { described_class.new([schema1]) }

    it "returns REFERENCE FROM references for a schema" do
      result = index.reference_references("schema1")

      expect(result).to be_an(Array)
      expect(result.first[:schema]).to eq("other_schema")
    end

    it "returns empty array for schema without REFERENCE FROM" do
      result = index.reference_references("schema2")

      expect(result).to eq([])
    end

    it "handles case-insensitive schema names" do
      result = index.reference_references("SCHEMA1")

      expect(result).to be_an(Array)
      expect(result).not_to be_empty
    end

    it "returns empty array for non-existent schema" do
      result = index.reference_references("nonexistent")

      expect(result).to eq([])
    end
  end

  describe "#schema_dependencies" do
    let(:index) { described_class.new([schema1]) }

    it "returns all dependencies for a schema" do
      result = index.schema_dependencies("schema1")

      expect(result).to be_a(Set)
      expect(result).to include("referenced_schema", "other_schema")
    end

    it "returns empty set for schema without dependencies" do
      result = index.schema_dependencies("schema2")

      expect(result).to be_a(Set)
      expect(result).to be_empty
    end

    it "handles case-insensitive schema names" do
      result = index.schema_dependencies("SCHEMA1")

      expect(result).to be_a(Set)
      expect(result).not_to be_empty
    end

    it "returns empty set for non-existent schema" do
      result = index.schema_dependencies("nonexistent")

      expect(result).to be_a(Set)
      expect(result).to be_empty
    end
  end

  describe "#detect_circular_dependencies" do
    context "with no circular dependencies" do
      let(:index) { described_class.new([schema1, schema2]) }

      it "returns empty array when no cycles exist" do
        result = index.detect_circular_dependencies

        expect(result).to eq([])
      end
    end

    context "with circular dependencies" do
      let(:circular_schema1) do
        Expressir::Model::Declarations::Schema.new(
          id: "schema1",
          interfaces: [circular_interface1],
        )
      end

      let(:circular_schema2) do
        Expressir::Model::Declarations::Schema.new(
          id: "schema2",
          interfaces: [circular_interface2],
        )
      end

      let(:circular_schema3) do
        Expressir::Model::Declarations::Schema.new(
          id: "schema3",
          interfaces: [circular_interface3],
        )
      end

      it "detects simple circular dependency (A -> B -> A)" do
        two_way_interface1 = Expressir::Model::Declarations::Interface.new(
          kind: Expressir::Model::Declarations::Interface::USE,
          schema: Expressir::Model::Declarations::Schema.new(id: "schema2"),
          items: [],
        )
        two_way_interface2 = Expressir::Model::Declarations::Interface.new(
          kind: Expressir::Model::Declarations::Interface::USE,
          schema: Expressir::Model::Declarations::Schema.new(id: "schema1"),
          items: [],
        )
        s1 = Expressir::Model::Declarations::Schema.new(
          id: "schema1",
          interfaces: [two_way_interface1],
        )
        s2 = Expressir::Model::Declarations::Schema.new(
          id: "schema2",
          interfaces: [two_way_interface2],
        )
        index = described_class.new([s1, s2])

        result = index.detect_circular_dependencies

        expect(result).not_to be_empty
        expect(result.first).to be_an(Array)
      end

      it "detects complex circular dependency (A -> B -> C -> A)" do
        index = described_class.new([circular_schema1, circular_schema2,
                                     circular_schema3])

        result = index.detect_circular_dependencies

        expect(result).not_to be_empty
        expect(result.first).to be_an(Array)
      end
    end

    context "with self-referencing schema" do
      let(:self_ref_interface) do
        Expressir::Model::Declarations::Interface.new(
          kind: Expressir::Model::Declarations::Interface::USE,
          schema: Expressir::Model::Declarations::Schema.new(id: "self_ref"),
          items: [],
        )
      end

      let(:self_ref_schema) do
        Expressir::Model::Declarations::Schema.new(
          id: "self_ref",
          interfaces: [self_ref_interface],
        )
      end

      it "detects self-reference as circular dependency" do
        index = described_class.new([self_ref_schema])

        result = index.detect_circular_dependencies

        expect(result).not_to be_empty
      end
    end
  end

  describe "#empty?" do
    it "returns true for empty index" do
      index = described_class.new

      expect(index).to be_empty
    end

    it "returns false for non-empty index" do
      index = described_class.new([schema1])

      expect(index).not_to be_empty
    end

    it "returns true after building with empty schemas" do
      schema_no_interfaces = Expressir::Model::Declarations::Schema.new(
        id: "empty",
        interfaces: nil,
      )
      index = described_class.new([schema_no_interfaces])

      expect(index).to be_empty
    end
  end

  describe "#use_from_count" do
    it "returns zero for empty index" do
      index = described_class.new

      expect(index.use_from_count).to eq(0)
    end

    it "counts total USE FROM references" do
      index = described_class.new([schema1])

      expect(index.use_from_count).to eq(1)
    end

    it "counts across multiple schemas" do
      multi_use_schema = Expressir::Model::Declarations::Schema.new(
        id: "multi",
        interfaces: [use_interface, use_interface],
      )
      index = described_class.new([schema1, multi_use_schema])

      expect(index.use_from_count).to be >= 1
    end
  end

  describe "#reference_from_count" do
    it "returns zero for empty index" do
      index = described_class.new

      expect(index.reference_from_count).to eq(0)
    end

    it "counts total REFERENCE FROM references" do
      index = described_class.new([schema1])

      expect(index.reference_from_count).to eq(1)
    end

    it "counts across multiple schemas" do
      multi_ref_schema = Expressir::Model::Declarations::Schema.new(
        id: "multi",
        interfaces: [reference_interface, reference_interface],
      )
      index = described_class.new([schema1, multi_ref_schema])

      expect(index.reference_from_count).to be >= 1
    end
  end

  describe "reference tracking behavior" do
    let(:index) { described_class.new([schema1]) }

    it "tracks use references" do
      result = index.use_references("schema1")
      expect(result).to be_an(Array)
      expect(result).not_to be_empty
    end

    it "tracks reference references" do
      result = index.reference_references("schema1")
      expect(result).to be_an(Array)
      expect(result).not_to be_empty
    end

    it "tracks schema dependencies" do
      result = index.schema_dependencies("schema1")
      expect(result).to be_a(Set)
      expect(result).not_to be_empty
    end

    it "detects circular dependencies" do
      result = index.detect_circular_dependencies
      expect(result).to be_an(Array)
    end
  end

  describe "extensibility" do
    it "allows rebuilding indexes with different schemas" do
      index = described_class.new([schema1])
      expect(index.use_from_count).to eq(1)

      index.build([schema2])
      expect(index.use_from_count).to eq(0)

      index.build([schema1, schema2])
      expect(index.use_from_count).to eq(1)
    end

    it "supports complex dependency graph analysis" do
      index = described_class.new([schema1])

      # These methods exist and return expected types
      expect(index.schema_dependencies("schema1")).to be_a(Set)
      expect(index.detect_circular_dependencies).to be_a(Array)
    end
  end

  describe "edge cases" do
    let(:index) { described_class.new }

    it "handles interfaces with empty items list" do
      empty_items_interface = Expressir::Model::Declarations::Interface.new(
        kind: Expressir::Model::Declarations::Interface::USE,
        schema: Expressir::Model::Declarations::Schema.new(id: "target"),
        items: [],
      )
      schema_empty_items = Expressir::Model::Declarations::Schema.new(
        id: "source",
        interfaces: [empty_items_interface],
      )
      index.build([schema_empty_items])

      use_refs = index.use_references("source")
      expect(use_refs.first[:items]).to eq([])
    end
  end
end
