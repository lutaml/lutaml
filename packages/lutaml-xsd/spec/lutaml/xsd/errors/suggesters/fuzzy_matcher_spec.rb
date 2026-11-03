# frozen_string_literal: true

require "spec_helper"
require "lutaml/xsd/errors/suggesters/fuzzy_matcher"

RSpec.describe Lutaml::Xsd::Errors::Suggesters::FuzzyMatcher do
  let(:repository) { double("repository") }
  let(:matcher) { described_class.new(repository) }

  describe "#levenshtein_distance" do
    it "calculates edit distance" do
      expect(matcher.levenshtein_distance("kitten", "sitting")).to eq(3)
    end

    it "handles empty strings" do
      expect(matcher.levenshtein_distance("", "test")).to eq(4)
      expect(matcher.levenshtein_distance("test", "")).to eq(4)
    end

    it "handles identical strings" do
      expect(matcher.levenshtein_distance("test", "test")).to eq(0)
    end
  end

  describe "#similarity_score" do
    it "returns 1.0 for identical strings" do
      expect(matcher.similarity_score("test", "test")).to eq(1.0)
    end

    it "returns 0.0 for completely different strings" do
      score = matcher.similarity_score("abc", "xyz")
      expect(score).to be < 1.0
    end

    it "returns intermediate score for similar strings" do
      score = matcher.similarity_score("CodeType", "CdeType")
      expect(score).to be_between(0.5, 1.0)
    end

    it "is case-insensitive" do
      score1 = matcher.similarity_score("CodeType", "codetype")
      score2 = matcher.similarity_score("CodeType", "CODETYPE")
      expect(score1).to eq(score2)
      expect(score1).to eq(1.0)
    end
  end

  describe "#find_similar_types" do
    let(:simple_types) do
      [
        double("type", name: "CodeType"),
        double("type", name: "StringType"),
        double("type", name: "IntegerType"),
      ]
    end

    before do
      allow(repository).to receive(:simple_types).and_return(simple_types)
      allow(repository).to receive(:complex_types).and_return([])
    end

    it "finds similar types" do
      results = matcher.find_similar_types("CdeType", limit: 5)

      expect(results).not_to be_empty
      expect(results.first.text).to eq("CodeType")
    end

    it "respects limit parameter" do
      results = matcher.find_similar_types("Type", limit: 2)

      expect(results.size).to be <= 2
    end

    it "filters by minimum similarity" do
      matcher = described_class.new(repository, min_similarity: 0.8)
      results = matcher.find_similar_types("CodeType")

      results.each do |suggestion|
        expect(suggestion.similarity).to be >= 0.8
      end
    end

    it "returns suggestions sorted by similarity" do
      results = matcher.find_similar_types("Code", limit: 5)

      similarities = results.map(&:similarity)
      expect(similarities).to eq(similarities.sort.reverse)
    end

    it "returns empty array when no repository" do
      matcher = described_class.new(nil)
      results = matcher.find_similar_types("Type")

      expect(results).to be_empty
    end
  end
end
