# frozen_string_literal: true

require "spec_helper"

RSpec.describe Expressir::Model::Indexes::EntityIndex do
  # Use REAL objects instead of mocks
  let(:entity1) do
    Expressir::Model::Declarations::Entity.new(id: "entity1")
  end

  let(:entity2) do
    Expressir::Model::Declarations::Entity.new(id: "entity2")
  end

  let(:entity3) do
    Expressir::Model::Declarations::Entity.new(id: "entity3")
  end

  let(:schema1) do
    Expressir::Model::Declarations::Schema.new(
      id: "schema1",
      entities: [entity1, entity2],
    )
  end

  let(:schema2) do
    Expressir::Model::Declarations::Schema.new(
      id: "schema2",
      entities: [entity3],
    )
  end

  describe "#initialize" do
    it "creates an empty index when no schemas provided" do
      index = described_class.new

      expect(index.by_schema).to eq({})
      expect(index.by_qualified_name).to eq({})
    end

    it "builds indexes when schemas provided" do
      index = described_class.new([schema1])

      expect(index.by_schema).to have_key("schema1")
      expect(index.by_qualified_name).to have_key("schema1.entity1")
    end

    it "handles empty array" do
      index = described_class.new([])

      expect(index.by_schema).to eq({})
      expect(index.by_qualified_name).to eq({})
    end
  end

  describe "#build" do
    let(:index) { described_class.new }

    it "builds indexes from schemas" do
      index.build([schema1, schema2])

      expect(index.by_schema.keys).to contain_exactly("schema1", "schema2")
      expect(index.by_qualified_name.keys).to contain_exactly(
        "schema1.entity1",
        "schema1.entity2",
        "schema2.entity3",
      )
    end

    it "indexes entities by schema" do
      index.build([schema1])

      expect(index.by_schema["schema1"]).to include(
        "entity1" => entity1,
        "entity2" => entity2,
      )
    end

    it "indexes entities by qualified name" do
      index.build([schema1])

      expect(index.by_qualified_name["schema1.entity1"]).to eq(entity1)
      expect(index.by_qualified_name["schema1.entity2"]).to eq(entity2)
    end

    it "handles schemas with nil entities" do
      schema_no_entities = Expressir::Model::Declarations::Schema.new(
        id: "empty_schema",
        entities: nil,
      )

      expect { index.build([schema_no_entities]) }.not_to raise_error
      expect(index.by_schema["empty_schema"]).to eq({})
    end

    it "handles empty entities collection" do
      schema_empty_entities = Expressir::Model::Declarations::Schema.new(
        id: "empty_schema",
        entities: [],
      )

      index.build([schema_empty_entities])

      expect(index.by_schema["empty_schema"]).to eq({})
    end

    it "clears previous indexes on rebuild" do
      index.build([schema1])
      initial_count = index.count

      index.build([schema2])

      expect(index.count).not_to eq(initial_count)
      expect(index.by_qualified_name).not_to have_key("schema1.entity1")
      expect(index.by_qualified_name).to have_key("schema2.entity3")
    end
  end

  describe "#find" do
    let(:index) { described_class.new([schema1, schema2]) }

    context "with qualified name" do
      it "finds entity by qualified name" do
        result = index.find("schema1.entity1")

        expect(result).to eq(entity1)
      end

      it "handles case-insensitive qualified names" do
        result = index.find("SCHEMA1.ENTITY1")

        expect(result).to eq(entity1)
      end

      it "returns nil for non-existent qualified name" do
        result = index.find("schema1.nonexistent")

        expect(result).to be_nil
      end
    end

    context "with simple name" do
      it "finds entity by simple name across all schemas" do
        result = index.find("entity1")

        expect(result).to eq(entity1)
      end

      it "returns first match when simple name exists in multiple schemas" do
        duplicate_entity = Expressir::Model::Declarations::Entity.new(id: "entity1")
        schema_with_duplicate = Expressir::Model::Declarations::Schema.new(
          id: "schema3",
          entities: [duplicate_entity],
        )
        index.build([schema1, schema_with_duplicate])

        result = index.find("entity1")

        expect(result).not_to be_nil
        expect([entity1, duplicate_entity]).to include(result)
      end
    end

    context "with non-existent schema" do
      it "returns nil when schema does not exist" do
        result = index.find("nonexistent.entity1")

        expect(result).to be_nil
      end
    end

    it "returns nil for empty string" do
      result = index.find("")

      expect(result).to be_nil
    end
  end

  describe "#list" do
    let(:index) { described_class.new([schema1, schema2]) }

    context "without schema filter" do
      it "lists all entities" do
        result = index.list

        expect(result).to contain_exactly(entity1, entity2, entity3)
      end
    end

    context "with schema filter" do
      it "lists entities from specific schema" do
        result = index.list(schema: "schema1")

        expect(result).to contain_exactly(entity1, entity2)
      end

      it "returns empty array for non-existent schema" do
        result = index.list(schema: "nonexistent")

        expect(result).to eq([])
      end

      it "handles case-insensitive schema names" do
        result = index.list(schema: "SCHEMA1")

        expect(result).to contain_exactly(entity1, entity2)
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
      schema_no_entities = Expressir::Model::Declarations::Schema.new(
        id: "empty",
        entities: nil,
      )
      index = described_class.new([schema_no_entities])

      expect(index).to be_empty
    end
  end

  describe "#count" do
    it "returns zero for empty index" do
      index = described_class.new

      expect(index.count).to eq(0)
    end

    it "counts total entities across all schemas" do
      index = described_class.new([schema1, schema2])

      expect(index.count).to eq(3)
    end

    it "returns correct count after rebuild" do
      index = described_class.new([schema1])
      expect(index.count).to eq(2)

      index.build([schema2])

      expect(index.count).to eq(1)
    end
  end

  describe "#schema_entities" do
    let(:index) { described_class.new([schema1, schema2]) }

    it "returns entities hash for existing schema" do
      result = index.schema_entities("schema1")

      expect(result).to be_a(Hash)
      expect(result.values).to contain_exactly(entity1, entity2)
    end

    it "returns empty hash for non-existent schema" do
      result = index.schema_entities("nonexistent")

      expect(result).to eq({})
    end

    it "handles case-insensitive schema names" do
      result = index.schema_entities("SCHEMA1")

      expect(result).to be_a(Hash)
      expect(result.keys).to contain_exactly("entity1", "entity2")
    end
  end

  describe "entity indexing behavior" do
    let(:index) { described_class.new([schema1]) }

    it "finds entities by calling find method" do
      result = index.find("entity1")
      expect(result).to eq(entity1)
    end

    it "lists entities by calling list method" do
      result = index.list
      expect(result).to contain_exactly(entity1, entity2)
    end

    it "builds indexes by calling build method" do
      new_index = described_class.new
      new_index.build([schema1])
      expect(new_index.count).to eq(2)
    end
  end

  describe "extensibility" do
    it "allows rebuilding indexes with different schemas" do
      index = described_class.new([schema1])
      expect(index.count).to eq(2)

      index.build([schema2])
      expect(index.count).to eq(1)

      index.build([schema1, schema2])
      expect(index.count).to eq(3)
    end
  end
end
