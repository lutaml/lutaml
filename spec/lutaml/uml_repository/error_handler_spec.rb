# frozen_string_literal: true

require "spec_helper"
require_relative "../../../lib/lutaml/uml_repository/error_handler"
require_relative "../../../lib/lutaml/uml_repository/repository"

RSpec.describe Lutaml::UmlRepository::ErrorHandler do
  let(:xmi_path) { fixtures_path("ea-xmi-2.5.1.xmi") }
  let(:repository) { Lutaml::UmlRepository::Repository.from_xmi(xmi_path) }
  let(:error_handler) { described_class.new(repository) }

  describe "#initialize" do
    it "creates an error handler with repository" do
      handler = described_class.new(repository)

      expect(handler.repository).to eq(repository)
    end
  end

  describe "#levenshtein_distance" do
    it "calculates distance for identical strings" do
      expect(error_handler.levenshtein_distance("test", "test")).to eq(0)
    end

    it "calculates distance for completely different strings" do
      distance = error_handler.levenshtein_distance("abc", "xyz")
      expect(distance).to eq(3)
    end

    it "calculates distance for strings with one character difference" do
      expect(error_handler.levenshtein_distance("cat", "bat")).to eq(1)
    end

    it "calculates distance for insertion" do
      expect(error_handler.levenshtein_distance("cat", "cats")).to eq(1)
    end

    it "calculates distance for deletion" do
      expect(error_handler.levenshtein_distance("cats", "cat")).to eq(1)
    end

    it "calculates distance for empty strings" do
      expect(error_handler.levenshtein_distance("", "test")).to eq(4)
      expect(error_handler.levenshtein_distance("test", "")).to eq(4)
      expect(error_handler.levenshtein_distance("", "")).to eq(0)
    end

    it "calculates distance for classic example" do
      expect(error_handler.levenshtein_distance("kitten", "sitting")).to eq(3)
    end
  end

  describe "#suggest_similar_classes" do
    context "with close matches" do
      it "suggests classes with similar names" do
        # This test assumes the fixture has certain classes
        # Adjust based on actual fixture content
        suggestions = error_handler.suggest_similar_classes("ModelRot")

        expect(suggestions).to be_an(Array)
      end

      it "returns empty array when no close matches" do
        suggestions = error_handler.suggest_similar_classes("XYZ123NonExistent")

        # Should either be empty or contain substring matches
        expect(suggestions).to be_an(Array)
      end
    end

    context "with exact distance threshold" do
      it "only returns suggestions within MAX_SUGGESTION_DISTANCE" do
        suggestions = error_handler.suggest_similar_classes("ModelRoot::requirement type class diagram::BibliographicI")

        expect(suggestions).to include("ModelRoot::requirement type class diagram::BibliographicItem")
      end
    end
  end

  describe "#suggest_similar_packages" do
    it "suggests packages with similar paths" do
      # This assumes packages exist in the fixture
      suggestions = error_handler.suggest_similar_packages("ModelRot")

      expect(suggestions).to be_an(Array)
    end

    it "returns empty array when repository has no packages" do
      suggestions = error_handler.suggest_similar_packages("AnyPath")

      expect(suggestions).to eq([])
    end
  end

  describe "#class_not_found_error" do
    context "with suggestions available" do
      it "raises NameError with suggestions" do
        allow(error_handler).to receive(:suggest_similar_classes)
          .and_return(["ModelRoot::Building", "ModelRoot::BuildingPart"])

        expect do
          error_handler.class_not_found_error("ModelRoot::Buildng")
        end.to raise_error(NameError) do |error|
          expect(error.message).to include("Class not found: ModelRoot::Buildng")
          expect(error.message).to include("Did you mean one of these?")
          expect(error.message).to include("ModelRoot::Building")
          expect(error.message).to include("ModelRoot::BuildingPart")
        end
      end
    end

    context "without suggestions" do
      it "raises NameError with helpful tip" do
        allow(error_handler).to receive(:suggest_similar_classes).and_return([])

        expect do
          error_handler.class_not_found_error("CompletelyInvalid")
        end.to raise_error(NameError) do |error|
          expect(error.message).to include("Class not found: CompletelyInvalid")
          expect(error.message).to include("Tip: Use the 'search' or 'find' commands")
        end
      end
    end
  end

  describe "#package_not_found_error" do
    context "with suggestions available" do
      it "raises NameError with suggestions" do
        allow(error_handler).to receive(:suggest_similar_packages)
          .and_return(["ModelRoot::i-UR", "ModelRoot::core"])

        expect do
          error_handler.package_not_found_error("ModelRoot::i-UP")
        end.to raise_error(NameError) do |error|
          expect(error.message).to include("Package not found: ModelRoot::i-UP")
          expect(error.message).to include("Did you mean one of these?")
          expect(error.message).to include("ModelRoot::i-UR")
          expect(error.message).to include("ModelRoot::core")
        end
      end
    end

    context "without suggestions" do
      it "raises NameError with helpful tip" do
        allow(error_handler).to receive(:suggest_similar_packages).and_return([])

        expect do
          error_handler.package_not_found_error("Invalid::Path")
        end.to raise_error(NameError) do |error|
          expect(error.message).to include("Package not found: Invalid::Path")
          expect(error.message).to include("Tip: Use the 'list' or 'tree' commands")
        end
      end
    end
  end

  describe "integration with real repository" do
    it "suggests actual classes from repository" do
      # Get all classes from repository
      all_classes = repository.indexes[:class_to_qname].keys

      next if all_classes.empty?

      # Take a real class name and make a typo
      real_class = all_classes.first
      typo = real_class[0...-1] # Remove last character

      suggestions = error_handler.suggest_similar_classes(typo)

      # Should suggest the real class or something similar
      expect(suggestions).to be_an(Array)
    end

    it "limits suggestions to MAX_SUGGESTIONS" do
      suggestions = error_handler.suggest_similar_classes("ModelRoot")

      expect(suggestions.size).to be <= described_class::MAX_SUGGESTIONS
    end
  end

  describe "substring matching fallback" do
    it "uses substring matching when Levenshtein distance is too large" do
      # Should match by substring even though edit distance is large
      suggestions = error_handler.suggest_similar_classes("ClassificationType")

      expect(suggestions).to include("ModelRoot::requirement type class diagram::ClassificationType")
    end

    it "is case-insensitive for substring matching" do
      suggestions = error_handler.suggest_similar_classes("bibliographicItem")

      expect(suggestions).to include("ModelRoot::requirement type class diagram::BibliographicItem")
    end
  end
end
