# frozen_string_literal: true

require "spec_helper"

RSpec.describe Expressir::Model::Indexes::TypeIndex do
  # Use REAL objects instead of mocks
  let(:select_data_type) do
    Expressir::Model::DataTypes::Select.new(
      extensible: false,
      types: [],
    )
  end

  let(:select_type) do
    Expressir::Model::Declarations::Type.new(
      id: "select_type",
      underlying_type: select_data_type,
    )
  end

  let(:enum_data_type) do
    Expressir::Model::DataTypes::Enumeration.new(
      items: [
        Expressir::Model::DataTypes::EnumerationItem.new(id: "item1"),
      ],
    )
  end

  let(:enum_type) do
    Expressir::Model::Declarations::Type.new(
      id: "enum_type",
      underlying_type: enum_data_type,
    )
  end

  let(:array_data_type) do
    Expressir::Model::DataTypes::Array.new(
      bound1: Expressir::Model::Literals::Integer.new(value: 1),
      bound2: Expressir::Model::Literals::Integer.new(value: 10),
    )
  end

  let(:array_type) do
    Expressir::Model::Declarations::Type.new(
      id: "array_type",
      underlying_type: array_data_type,
    )
  end

  let(:defined_type) do
    Expressir::Model::Declarations::Type.new(
      id: "defined_type",
      underlying_type: nil,
    )
  end

  let(:schema1) do
    Expressir::Model::Declarations::Schema.new(
      id: "schema1",
      types: [select_type, enum_type],
    )
  end

  let(:schema2) do
    Expressir::Model::Declarations::Schema.new(
      id: "schema2",
      types: [array_type, defined_type],
    )
  end

  describe "#initialize" do
    it "creates an empty index when no schemas provided" do
      index = described_class.new

      expect(index.by_schema).to eq({})
      expect(index.by_qualified_name).to eq({})
      expect(index.by_category).to be_a(Hash)
    end

    it "builds indexes when schemas provided" do
      index = described_class.new([schema1])

      expect(index.by_schema).to have_key("schema1")
      expect(index.by_qualified_name).to have_key("schema1.select_type")
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
        "schema1.select_type",
        "schema1.enum_type",
        "schema2.array_type",
        "schema2.defined_type",
      )
    end

    it "indexes types by schema" do
      index.build([schema1])

      expect(index.by_schema["schema1"]).to include(
        "select_type" => select_type,
        "enum_type" => enum_type,
      )
    end

    it "indexes types by qualified name" do
      index.build([schema1])

      expect(index.by_qualified_name["schema1.select_type"]).to eq(select_type)
      expect(index.by_qualified_name["schema1.enum_type"]).to eq(enum_type)
    end

    it "indexes types by category" do
      index.build([schema1, schema2])

      expect(index.by_category["select"]).to include(select_type)
      expect(index.by_category["enumeration"]).to include(enum_type)
      expect(index.by_category["aggregate"]).to include(array_type)
      expect(index.by_category["defined"]).to include(defined_type)
    end

    it "handles schemas with nil types" do
      schema_no_types = Expressir::Model::Declarations::Schema.new(
        id: "empty_schema",
        types: nil,
      )

      expect { index.build([schema_no_types]) }.not_to raise_error
      expect(index.by_schema["empty_schema"]).to eq({})
    end

    it "handles empty types collection" do
      schema_empty_types = Expressir::Model::Declarations::Schema.new(
        id: "empty_schema",
        types: [],
      )

      index.build([schema_empty_types])

      expect(index.by_schema["empty_schema"]).to eq({})
    end

    it "clears previous indexes on rebuild" do
      index.build([schema1])
      index.count

      index.build([schema2])

      expect(index.count).to eq(2) # Both types in schema2
      expect(index.by_qualified_name).not_to have_key("schema1.select_type")
      expect(index.by_qualified_name).to have_key("schema2.array_type")
    end
  end

  describe "#find" do
    let(:index) { described_class.new([schema1, schema2]) }

    context "with qualified name" do
      it "finds type by qualified name" do
        result = index.find("schema1.select_type")

        expect(result).to eq(select_type)
      end

      it "handles case-insensitive qualified names" do
        result = index.find("SCHEMA1.SELECT_TYPE")

        expect(result).to eq(select_type)
      end

      it "returns nil for non-existent qualified name" do
        result = index.find("schema1.nonexistent")

        expect(result).to be_nil
      end
    end

    context "with simple name" do
      it "finds type by simple name across all schemas" do
        result = index.find("select_type")

        expect(result).to eq(select_type)
      end

      it "returns first match when simple name exists in multiple schemas" do
        duplicate_type = Expressir::Model::Declarations::Type.new(
          id: "select_type",
          underlying_type: select_data_type,
        )
        schema_with_duplicate = Expressir::Model::Declarations::Schema.new(
          id: "schema3",
          types: [duplicate_type],
        )
        index.build([schema1, schema_with_duplicate])

        result = index.find("select_type")

        expect(result).not_to be_nil
        expect([select_type, duplicate_type]).to include(result)
      end
    end

    context "with non-existent schema" do
      it "returns nil when schema does not exist" do
        result = index.find("nonexistent.select_type")

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

    context "without filters" do
      it "lists all types" do
        result = index.list

        expect(result).to contain_exactly(select_type, enum_type, array_type,
                                          defined_type)
      end
    end

    context "with schema filter" do
      it "lists types from specific schema" do
        result = index.list(schema: "schema1")

        expect(result).to contain_exactly(select_type, enum_type)
      end

      it "returns empty array for non-existent schema" do
        result = index.list(schema: "nonexistent")

        expect(result).to eq([])
      end

      it "handles case-insensitive schema names" do
        result = index.list(schema: "SCHEMA1")

        expect(result).to contain_exactly(select_type, enum_type)
      end
    end

    context "with category filter" do
      it "lists types by category" do
        result = index.list(category: "select")

        expect(result).to contain_exactly(select_type)
      end

      it "returns empty array for non-existent category" do
        result = index.list(category: "nonexistent")

        expect(result).to eq([])
      end

      it "filters enumeration types" do
        result = index.list(category: "enumeration")

        expect(result).to contain_exactly(enum_type)
      end

      it "filters aggregate types" do
        result = index.list(category: "aggregate")

        expect(result).to contain_exactly(array_type)
      end

      it "filters defined types" do
        result = index.list(category: "defined")

        expect(result).to contain_exactly(defined_type)
      end
    end

    context "with schema and category filters" do
      it "applies both filters" do
        result = index.list(schema: "schema1", category: "select")

        expect(result).to contain_exactly(select_type)
      end

      it "returns empty array when filters don't match" do
        result = index.list(schema: "schema2", category: "select")

        expect(result).to eq([])
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
      schema_no_types = Expressir::Model::Declarations::Schema.new(
        id: "empty",
        types: nil,
      )
      index = described_class.new([schema_no_types])

      expect(index).to be_empty
    end
  end

  describe "#count" do
    it "returns zero for empty index" do
      index = described_class.new

      expect(index.count).to eq(0)
    end

    it "counts total types across all schemas" do
      index = described_class.new([schema1, schema2])

      expect(index.count).to eq(4)
    end

    it "returns correct count after rebuild" do
      index = described_class.new([schema1])
      expect(index.count).to eq(2)

      index.build([schema2])

      expect(index.count).to eq(2)
    end
  end

  describe "#schema_types" do
    let(:index) { described_class.new([schema1, schema2]) }

    it "returns types hash for existing schema" do
      result = index.schema_types("schema1")

      expect(result).to be_a(Hash)
      expect(result.values).to contain_exactly(select_type, enum_type)
    end

    it "returns empty hash for non-existent schema" do
      result = index.schema_types("nonexistent")

      expect(result).to eq({})
    end

    it "handles case-insensitive schema names" do
      result = index.schema_types("SCHEMA1")

      expect(result).to be_a(Hash)
      expect(result.keys).to contain_exactly("select_type", "enum_type")
    end
  end

  describe "#category_types" do
    let(:index) { described_class.new([schema1, schema2]) }

    it "returns types for select category" do
      result = index.category_types("select")

      expect(result).to contain_exactly(select_type)
    end

    it "returns types for enumeration category" do
      result = index.category_types("enumeration")

      expect(result).to contain_exactly(enum_type)
    end

    it "returns types for aggregate category" do
      result = index.category_types("aggregate")

      expect(result).to contain_exactly(array_type)
    end

    it "returns types for defined category" do
      result = index.category_types("defined")

      expect(result).to contain_exactly(defined_type)
    end

    it "returns empty array for non-existent category" do
      result = index.category_types("nonexistent")

      expect(result).to eq([])
    end
  end

  describe "#categorize" do
    let(:index) { described_class.new }

    it "categorizes select types" do
      result = index.categorize(select_type)

      expect(result).to eq("select")
    end

    it "categorizes enumeration types" do
      result = index.categorize(enum_type)

      expect(result).to eq("enumeration")
    end

    it "categorizes array types as aggregate" do
      result = index.categorize(array_type)

      expect(result).to eq("aggregate")
    end

    it "categorizes bag types as aggregate" do
      bag_data = Expressir::Model::DataTypes::Bag.new
      bag_type = Expressir::Model::Declarations::Type.new(
        underlying_type: bag_data,
      )

      result = index.categorize(bag_type)

      expect(result).to eq("aggregate")
    end

    it "categorizes list types as aggregate" do
      list_data = Expressir::Model::DataTypes::List.new
      list_type = Expressir::Model::Declarations::Type.new(
        underlying_type: list_data,
      )

      result = index.categorize(list_type)

      expect(result).to eq("aggregate")
    end

    it "categorizes set types as aggregate" do
      set_data = Expressir::Model::DataTypes::Set.new
      set_type = Expressir::Model::Declarations::Type.new(
        underlying_type: set_data,
      )

      result = index.categorize(set_type)

      expect(result).to eq("aggregate")
    end

    it "categorizes types without underlying_type as defined" do
      result = index.categorize(defined_type)

      expect(result).to eq("defined")
    end

    it "categorizes unknown types as defined" do
      unknown_type = Expressir::Model::Declarations::Type.new(
        underlying_type: Expressir::Model::DataTypes::String.new,
      )

      result = index.categorize(unknown_type)

      expect(result).to eq("defined")
    end
  end

  describe "type indexing behavior" do
    let(:index) { described_class.new([schema1]) }

    it "finds types by calling find method" do
      result = index.find("select_type")
      expect(result).to eq(select_type)
    end

    it "lists types by calling list method" do
      result = index.list
      expect(result).to contain_exactly(select_type, enum_type)
    end

    it "builds indexes by calling build method" do
      new_index = described_class.new
      new_index.build([schema1])
      expect(new_index.count).to eq(2)
    end

    it "categorizes types by calling categorize method" do
      result = index.categorize(select_type)
      expect(result).to eq("select")
    end
  end

  describe "extensibility" do
    it "allows rebuilding indexes with different schemas" do
      index = described_class.new([schema1])
      expect(index.count).to eq(2)

      index.build([schema2])
      expect(index.count).to eq(2)

      index.build([schema1, schema2])
      expect(index.count).to eq(4)
    end
  end
end
