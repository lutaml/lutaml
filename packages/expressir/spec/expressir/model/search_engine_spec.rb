# frozen_string_literal: true

require "spec_helper"
require "expressir/model/search_engine"
require "expressir/model/repository"

RSpec.describe Expressir::Model::SearchEngine do
  let(:repo) do
    # Create a simple test repository
    repo = Expressir::Model::Repository.new

    # Create test schema 1
    schema1 = Expressir::Model::Declarations::Schema.new(id: "test_schema")

    # Add entities
    entity1 = Expressir::Model::Declarations::Entity.new(id: "action")
    entity1.parent = schema1
    attr1 = Expressir::Model::Declarations::Attribute.new(id: "name")
    attr1.parent = entity1
    attr2 = Expressir::Model::Declarations::Attribute.new(id: "id")
    attr2.parent = entity1
    entity1.attributes = [attr1, attr2]

    entity2 = Expressir::Model::Declarations::Entity.new(id: "action_request")
    entity2.parent = schema1

    schema1.entities = [entity1, entity2]

    # Add types
    type1 = Expressir::Model::Declarations::Type.new(id: "identifier")
    type1.parent = schema1
    type1.underlying_type = Expressir::Model::DataTypes::String.new

    schema1.types = [type1]

    # Add functions
    func1 = Expressir::Model::Declarations::Function.new(id: "my_function")
    func1.parent = schema1
    param1 = Expressir::Model::Declarations::Parameter.new(id: "param1")
    param1.parent = func1
    func1.parameters = [param1]

    schema1.functions = [func1]

    repo.add_schema(schema1)

    # Create test schema 2
    schema2 = Expressir::Model::Declarations::Schema.new(id: "other_schema")

    entity3 = Expressir::Model::Declarations::Entity.new(id: "point")
    entity3.parent = schema2
    schema2.entities = [entity3]

    repo.add_schema(schema2)

    repo.build_indexes
    repo
  end

  let(:search_engine) { described_class.new(repo) }

  describe "#initialize" do
    it "initializes with a repository" do
      expect(search_engine.repository).to eq(repo)
    end

    it "builds indexes if not already built" do
      new_repo = Expressir::Model::Repository.new
      expect(new_repo).to receive(:build_indexes)
      described_class.new(new_repo)
    end
  end

  describe "#list" do
    context "when listing schemas" do
      it "returns all schemas" do
        results = search_engine.list(type: "schema")
        expect(results.size).to eq(2)
        expect(results.map do |r|
          r[:id]
        end).to contain_exactly("test_schema", "other_schema")
      end
    end

    context "when listing entities" do
      it "returns all entities" do
        results = search_engine.list(type: "entity")
        expect(results.size).to eq(3)
        expect(results.map do |r|
          r[:id]
        end).to contain_exactly("action", "action_request", "point")
      end

      it "filters entities by schema" do
        results = search_engine.list(type: "entity", schema: "test_schema")
        expect(results.size).to eq(2)
        expect(results.map do |r|
          r[:id]
        end).to contain_exactly("action", "action_request")
      end
    end

    context "when listing attributes" do
      it "returns all attributes" do
        results = search_engine.list(type: "attribute")
        expect(results.size).to eq(2)
        expect(results.map { |r| r[:id] }).to contain_exactly("name", "id")
      end
    end

    context "when listing types" do
      it "returns all types" do
        results = search_engine.list(type: "type")
        expect(results.size).to eq(1)
        expect(results.first[:id]).to eq("identifier")
      end
    end

    context "when listing functions" do
      it "returns all functions" do
        results = search_engine.list(type: "function")
        expect(results.size).to eq(1)
        expect(results.first[:id]).to eq("my_function")
      end
    end

    context "when listing parameters" do
      it "returns all parameters" do
        results = search_engine.list(type: "parameter")
        expect(results.size).to eq(1)
        expect(results.first[:id]).to eq("param1")
      end
    end
  end

  describe "#search" do
    context "with simple pattern" do
      it "finds entities by simple name" do
        results = search_engine.search(pattern: "action", type: "entity")
        expect(results.size).to be >= 1
        expect(results.any? { |r| r[:id] == "action" }).to be true
      end

      it "finds entities case-insensitively by default" do
        results = search_engine.search(pattern: "ACTION", type: "entity")
        expect(results.size).to be >= 1
      end

      it "finds entities case-sensitively when requested" do
        results = search_engine.search(pattern: "ACTION", type: "entity",
                                       case_sensitive: true)
        expect(results.size).to eq(0)
      end
    end

    context "with wildcard patterns" do
      it "matches prefix with wildcard" do
        results = search_engine.search(pattern: "action*", type: "entity")
        expect(results.size).to be >= 2
        expect(results.map do |r|
          r[:id]
        end).to include("action", "action_request")
      end

      it "matches schema wildcard" do
        results = search_engine.search(pattern: "*.action", type: "entity")
        expect(results.any? { |r| r[:id] == "action" }).to be true
      end

      it "matches element wildcard" do
        results = search_engine.search(pattern: "test_schema.*", type: "entity")
        expect(results.size).to eq(2)
      end

      it "matches attribute with deep path wildcard" do
        results = search_engine.search(pattern: "*.*.name", type: "attribute")
        expect(results.any? { |r| r[:id] == "name" }).to be true
      end
    end

    context "with exact matching" do
      it "matches exactly when exact option is true" do
        results = search_engine.search(pattern: "test_schema.action",
                                       type: "entity", exact: true)
        expect(results.size).to eq(1)
        expect(results.first[:id]).to eq("action")
      end

      it "does not match partial when exact is true" do
        results = search_engine.search(pattern: "action", type: "entity",
                                       exact: true)
        expect(results.size).to eq(0)
      end
    end

    context "with regex patterns" do
      it "matches using regex" do
        results = search_engine.search(pattern: "^action", type: "entity",
                                       regex: true)
        expect(results.size).to be >= 2
      end

      it "handles invalid regex gracefully" do
        results = search_engine.search(pattern: "[invalid(", type: "entity",
                                       regex: true)
        expect(results).to eq([])
      end
    end

    context "with schema filter" do
      it "limits search to specified schema" do
        results = search_engine.search(pattern: "action",
                                       schema: "test_schema", type: "entity")
        expect(results.all? { |r| r[:schema] == "test_schema" }).to be true
      end
    end

    context "without type filter" do
      it "searches across all element types" do
        results = search_engine.search(pattern: "identifier")
        expect(results.size).to be >= 1
        expect(results.any? { |r| r[:type] == "type" }).to be true
      end
    end
  end

  describe "#count" do
    it "counts entities" do
      count = search_engine.count(type: "entity")
      expect(count).to eq(3)
    end

    it "counts entities in a schema" do
      count = search_engine.count(type: "entity", schema: "test_schema")
      expect(count).to eq(2)
    end

    it "counts attributes" do
      count = search_engine.count(type: "attribute")
      expect(count).to eq(2)
    end
  end

  describe "element type coverage" do
    it "supports all documented element types" do
      types = described_class::ELEMENT_TYPES
      expect(types).to include(
        "schema", "entity", "type", "attribute",
        "function", "procedure", "rule", "constant",
        "parameter", "variable", "where_rule", "unique_rule",
        "enumeration_item", "interface"
      )
    end
  end

  describe "result format" do
    it "includes id in results" do
      results = search_engine.list(type: "entity")
      expect(results.first).to have_key(:id)
    end

    it "includes type in results" do
      results = search_engine.list(type: "entity")
      expect(results.first).to have_key(:type)
    end

    it "includes path in results" do
      results = search_engine.list(type: "entity")
      expect(results.first).to have_key(:path)
    end

    it "includes schema for non-schema elements" do
      results = search_engine.list(type: "entity")
      expect(results.first).to have_key(:schema)
    end

    it "includes category for type elements" do
      results = search_engine.list(type: "type")
      expect(results.first).to have_key(:category)
    end
  end
end
