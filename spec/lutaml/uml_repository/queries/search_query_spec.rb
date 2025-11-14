# frozen_string_literal: true

require "spec_helper"

RSpec.describe Lutaml::UmlRepository::Queries::SearchQuery do
  let(:document) { create_test_document }
  let(:indexes) { Lutaml::UmlRepository::IndexBuilder.build_all(document) }
  let(:query) { described_class.new(document, indexes) }

  describe "#search_classes" do
    it "searches classes by name pattern" do
      results = query.search_classes("*")
      expect(results).to be_an(Array)
      results.each do |klass|
        expect(klass).to be_a(Lutaml::Uml::Class)
      end
    end

    it "searches with glob patterns" do
      results = query.search_classes("*Type")
      expect(results).to be_an(Array)
      results.each do |klass|
        expect(klass.name).to match(/Type$/)
      end
    end

    it "returns empty array when no matches" do
      results = query.search_classes("NonExistentPattern")
      expect(results).to eq([])
    end

    it "handles case-sensitive search" do
      results = query.search_classes("*requirement*", case_sensitive: false)
      expect(results).to be_an(Array)
    end
  end

  describe "#search_packages" do
    it "searches packages by path pattern" do
      results = query.search_packages("*")
      expect(results).to be_an(Array)
      results.each do |pkg|
        expect(pkg).to be_a(Lutaml::Uml::Package)
      end
    end

    it "searches with glob patterns" do
      results = query.search_packages("EA_Model")
      expect(results).to be_an(Array)
    end

    it "returns empty array when no matches" do
      results = query.search_packages("NonExistent::Package")
      expect(results).to eq([])
    end
  end

  describe "#search_by_stereotype" do
    it "searches classes by stereotype pattern" do
      stereotypes = indexes[:stereotypes].keys.compact

      stereotypes.each do |stereotype|
        results = query.search_by_stereotype(stereotype)
        expect(results).to be_an(Array)
        results.each do |klass|
          expect(klass.stereotype).to eq(stereotype)
        end
      end
    end

    it "handles wildcard patterns" do
      results = query.search_by_stereotype("*")
      expect(results).to be_an(Array)
    end

    it "returns empty array when no matches" do
      results = query.search_by_stereotype("NonExistentStereotype")
      expect(results).to eq([])
    end
  end

  describe "#search_attributes" do
    it "searches attributes across all classes" do
      results = query.search_attributes("*")
      expect(results).to be_an(Array)
    end

    it "finds attributes by name pattern" do
      results = query.search_attributes("id")
      expect(results).to be_an(Array)
      results.each do |result|
        expect(result).to have_key(:class)
        expect(result).to have_key(:attribute)
        expect(result[:class]).to be_a(Lutaml::Uml::Class)
      end
    end

    it "returns empty array when no matches" do
      results = query.search_attributes("NonExistentAttribute")
      expect(results).to eq([])
    end
  end

  describe "#full_text_search" do
    it "searches across all text fields" do
      results = query.full_text_search("requirement")
      expect(results).to be_a(Hash)
      expect(results).to have_key(:classes)
      expect(results).to have_key(:packages)
    end

    it "searches in class names" do
      results = query.full_text_search("Requirement")
      expect(results[:classes]).to be_an(Array)
    end

    it "searches in package names" do
      results = query.full_text_search("Model")
      expect(results[:packages]).to be_an(Array)
    end

    it "returns empty results when no matches" do
      results = query.full_text_search("XyzNonExistent123")
      expect(results[:classes]).to eq([])
      expect(results[:packages]).to eq([])
    end

    it "handles case-insensitive search" do
      results = query.full_text_search("requirement", case_sensitive: false)
      expect(results).to be_a(Hash)
    end
  end

  describe "with simple document" do
    let(:document) { create_simple_test_document }

    it "searches for test class" do
      results = query.search_classes("TestClass")
      expect(results.length).to eq(1)
      expect(results.first.name).to eq("TestClass")
    end

    it "searches for test package" do
      results = query.search_packages("*::RootPackage")
      expect(results.length).to eq(1)
      expect(results.first.name).to eq("RootPackage")
    end

    it "searches by test stereotype" do
      results = query.search_by_stereotype("TestStereotype")
      expect(results.length).to eq(1)
      expect(results.first.name).to eq("TestClass")
    end

    it "performs full text search" do
      results = query.full_text_search("Test")
      expect(results[:classes]).not_to be_empty
      expect(results[:packages]).not_to be_empty
    end
  end
end
