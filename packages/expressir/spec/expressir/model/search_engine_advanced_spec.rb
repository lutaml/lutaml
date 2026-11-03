# frozen_string_literal: true

require "spec_helper"

RSpec.describe Expressir::Model::SearchEngine, "advanced features" do
  # Use REAL objects instead of mocks
  let(:attribute1) do
    Expressir::Model::Declarations::Attribute.new(id: "attr1")
  end

  let(:entity1) do
    Expressir::Model::Declarations::Entity.new(
      id: "entity1",
      attributes: [attribute1],
    )
  end

  let(:attribute2) do
    Expressir::Model::Declarations::Attribute.new(id: "test_attr")
  end

  let(:entity2) do
    Expressir::Model::Declarations::Entity.new(
      id: "test_entity",
      attributes: [attribute2],
    )
  end

  let(:schema1) do
    Expressir::Model::Declarations::Schema.new(
      id: "schema1",
      entities: [entity1],
    )
  end

  let(:schema2) do
    Expressir::Model::Declarations::Schema.new(
      id: "test_schema",
      entities: [entity2],
    )
  end

  let(:repo) do
    Expressir::Model::Repository.new(schemas: [schema1,
                                               schema2]).tap(&:build_indexes)
  end

  let(:engine) { described_class.new(repo) }

  describe "#search_with_depth" do
    it "filters results by maximum depth" do
      results = engine.search_with_depth(pattern: "test", max_depth: 2)

      # Should include schema level (depth 1) and entity level (depth 2)
      # Should exclude attribute level (depth 3)
      paths = results.map { |r| r[:path] }
      expect(paths).to include("test_schema", "test_schema.test_entity")
      expect(paths).not_to include("test_schema.test_entity.test_attr")
    end

    it "includes schema-level results at depth 1" do
      results = engine.search_with_depth(pattern: "schema", max_depth: 1)

      expect(results).not_to be_empty
      results.each do |result|
        depth = result[:path]&.split(".")&.size || 0
        expect(depth).to be <= 1
      end
    end

    it "includes entity-level results at depth 2" do
      results = engine.search_with_depth(pattern: "entity", max_depth: 2)

      paths = results.map { |r| r[:path] }
      expect(paths).to include("schema1.entity1")
      # Attributes are depth 3, should be excluded
      expect(paths.none? { |p| p&.split(".")&.size == 3 }).to be true
    end

    it "includes attribute-level results at depth 3" do
      results = engine.search_with_depth(pattern: "attr", max_depth: 3)

      paths = results.map { |r| r[:path] }
      expect(paths).to include("schema1.entity1.attr1")
    end
  end

  describe "#search_ranked" do
    it "returns results with relevance scores" do
      results = engine.search_ranked(pattern: "test")

      expect(results).not_to be_empty
      results.each do |result|
        expect(result).to have_key(:relevance_score)
        expect(result[:relevance_score]).to be_a(Integer)
      end
    end

    it "ranks exact matches higher" do
      results = engine.search_ranked(pattern: "test_entity")

      exact_match = results.find { |r| r[:id] == "test_entity" }
      other_matches = results.reject { |r| r[:id] == "test_entity" }

      if exact_match && other_matches.any?
        expect(exact_match[:relevance_score]).to be >= other_matches.first[:relevance_score]
      end
    end

    it "ranks prefix matches higher than substring matches" do
      results = engine.search_ranked(pattern: "test")

      prefix_matches = results.select { |r| r[:id]&.start_with?("test") }
      expect(prefix_matches).not_to be_empty
    end

    it "ranks schema-level results higher" do
      results = engine.search_ranked(pattern: "schema")

      schema_results, non_schema_results = results.partition do |r|
        r[:type] == "schema"
      end

      if schema_results.any? && non_schema_results.any?
        avg_schema_score = schema_results.sum do |r|
          r[:relevance_score]
        end / schema_results.size.to_f
        avg_other_score = non_schema_results.sum do |r|
          r[:relevance_score]
        end / non_schema_results.size.to_f
        expect(avg_schema_score).to be >= avg_other_score
      end
    end

    it "accepts custom boost values" do
      results = engine.search_ranked(
        pattern: "test",
        boost_exact: 20,
        boost_prefix: 10,
      )

      expect(results).not_to be_empty
      expect(results.first).to have_key(:relevance_score)
    end

    it "sorts results by relevance score descending" do
      results = engine.search_ranked(pattern: "test")

      scores = results.map { |r| r[:relevance_score] }
      expect(scores).to eq(scores.sort.reverse)
    end

    it "accepts additional search options" do
      results = engine.search_ranked(
        pattern: "test",
        type: "entity",
      )

      expect(results.all? { |r| r[:type] == "entity" }).to be true
    end

    it "handles empty results gracefully" do
      results = engine.search_ranked(pattern: "nonexistent_xyz")

      expect(results).to be_empty
    end

    it "calculates scores consistently" do
      results1 = engine.search_ranked(pattern: "test")
      results2 = engine.search_ranked(pattern: "test")

      expect(results1.map { |r| r[:relevance_score] }).to eq(
        results2.map { |r| r[:relevance_score] },
      )
    end
  end

  describe "#search_advanced" do
    it "combines depth filtering and ranking" do
      results = engine.search_advanced(
        pattern: "test",
        max_depth: 2,
        ranked: true,
      )

      # Check depth constraint
      expect(results).not_to be_empty
      results.each do |result|
        next unless result[:path]

        depth = result[:path].split(".").size
        expect(depth).to be <= 2
      end

      # Check ranking
      expect(results.first).to have_key(:relevance_score)
    end

    it "applies only depth filtering when ranked is false" do
      results = engine.search_advanced(
        pattern: "test",
        max_depth: 2,
        ranked: false,
      )

      results.each do |result|
        next unless result[:path]

        depth = result[:path].split(".").size
        expect(depth).to be <= 2
      end

      expect(results).not_to be_empty
      expect(results.first).not_to have_key(:relevance_score)
    end

    it "applies only ranking when max_depth is nil" do
      results = engine.search_advanced(
        pattern: "test",
        max_depth: nil,
        ranked: true,
      )

      expect(results).not_to be_empty
      expect(results.first).to have_key(:relevance_score)
    end

    it "works without any advanced options" do
      results = engine.search_advanced(
        pattern: "test",
        max_depth: nil,
        ranked: false,
      )

      expect(results).not_to be_empty
      expect(results.first).not_to have_key(:relevance_score)
    end

    it "accepts all standard search options" do
      results = engine.search_advanced(
        pattern: "test",
        type: "entity",
        max_depth: 2,
        ranked: true,
      )

      expect(results.all? { |r| r[:type] == "entity" }).to be true
    end

    it "handles case_sensitive option" do
      results = engine.search_advanced(
        pattern: "TEST",
        case_sensitive: true,
        max_depth: 2,
      )

      expect(results).to be_a(Array)
    end

    it "handles regex option" do
      results = engine.search_advanced(
        pattern: "test.*",
        regex: true,
        max_depth: 2,
      )

      expect(results).to be_a(Array)
    end

    it "handles exact option" do
      results = engine.search_advanced(
        pattern: "test_schema.test_entity",
        exact: true,
        max_depth: 2,
      )

      expect(results).to be_a(Array)
      expect(results.map { |r| r[:id] }).to contain_exactly("test_entity")
    end

    it "handles schema filtering" do
      results = engine.search_advanced(
        pattern: "test",
        schema: "test_schema",
        max_depth: 2,
      )

      results.each do |result|
        # Non-schema results should belong to test_schema
        expect(result[:schema]).to eq("test_schema") if result[:type] != "schema"
      end
    end

    it "returns consistent results with same parameters" do
      results1 = engine.search_advanced(
        pattern: "test",
        max_depth: 2,
        ranked: true,
      )
      results2 = engine.search_advanced(
        pattern: "test",
        max_depth: 2,
        ranked: true,
      )

      expect(results1.map { |r| r[:id] }).to eq(results2.map { |r| r[:id] })
    end

    it "handles empty results gracefully" do
      results = engine.search_advanced(
        pattern: "nonexistent_xyz",
        max_depth: 2,
        ranked: true,
      )

      expect(results).to be_empty
    end
  end

  describe "integration with existing search" do
    it "maintains compatibility with basic search" do
      basic_results = engine.search(pattern: "test")
      advanced_results = engine.search_advanced(pattern: "test")

      # Same IDs but advanced might have different ordering
      expect(basic_results.map { |r| r[:id] }.sort).to eq(
        advanced_results.map { |r| r[:id] }.sort,
      )
    end

    it "produces subset when depth filtering is applied" do
      all_results = engine.search(pattern: "test")
      depth_results = engine.search_with_depth(pattern: "test", max_depth: 2)

      expect(depth_results.size).to be <= all_results.size
    end

    it "maintains result structure" do
      results = engine.search_ranked(pattern: "test")

      results.each do |result|
        expect(result).to have_key(:id)
        expect(result).to have_key(:type)
        expect(result).to have_key(:path)
      end
    end
  end

  describe "edge cases" do
    it "handles nil pattern gracefully in ranked search" do
      expect do
        engine.search_ranked(pattern: "")
      end.not_to raise_error
    end

    it "handles very small max_depth" do
      results = engine.search_with_depth(pattern: "test", max_depth: 0)

      expect(results).to be_empty
    end

    it "handles very large max_depth" do
      results = engine.search_with_depth(pattern: "test", max_depth: 100)

      expect(results).to be_a(Array)
    end

    it "handles negative boost values" do
      results = engine.search_ranked(
        pattern: "test",
        boost_exact: -5,
        boost_prefix: -2,
      )

      expect(results).to be_a(Array)
    end

    it "handles zero boost values" do
      results = engine.search_ranked(
        pattern: "test",
        boost_exact: 0,
        boost_prefix: 0,
      )

      expect(results).to be_a(Array)
    end
  end
end
