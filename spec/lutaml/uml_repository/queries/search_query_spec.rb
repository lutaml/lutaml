# frozen_string_literal: true

require "spec_helper"
require_relative "../../../../lib/lutaml/uml_repository/index_builder"

RSpec.describe Lutaml::UmlRepository::Queries::SearchQuery do
  let(:document) { create_test_document }
  let(:indexes) { Lutaml::UmlRepository::IndexBuilder.build_all(document) }
  let(:query) { described_class.new(document, indexes) }

  describe "#search_classes" do
    it "searches classes by exact match" do
      results = query.search_classes("RequirementType")

      expect(results).to be_an(Array)
      expect(results.count).to eq(1)

      results.each do |result|
        expect(result).to be_a(Lutaml::UmlRepository::SearchResult)
        expect(result.element).to be_a(Lutaml::Uml::Class)
        expect(result.element_type).to eq("class")
        expect(result.qualified_name)
          .to eq("ModelRoot::requirement type class diagram::RequirementType")
        expect(result.package_path)
          .to eq("ModelRoot::requirement type class diagram")
        expect(result.match_field).to eq("name")
      end
    end
    it "searches classes by wildcard pattern" do
      results = query.search_classes("*")

      expect(results).to be_an(Array)
      results.each do |result|
        expect(result).to be_a(Lutaml::UmlRepository::SearchResult)
        expect(result.element).to be_a(Lutaml::Uml::Class)
      end
      expect(results.count).to eq(8)
    end

    it "searches with glob patterns" do
      results = query.search_classes("*Type")

      expect(results).to be_an(Array)
      results.each do |result|
        expect(result).to be_a(Lutaml::UmlRepository::SearchResult)
        expect(result.element).to be_a(Lutaml::Uml::Class)
        expect(result.element.name).to match(/.*Type/)
      end
      # ClassificationType and RequirementType
      expect(results.count).to eq(2)
    end

    it "searches with regex patterns" do
      results = query.search_classes(".*Type")

      expect(results).to be_an(Array)
      results.each do |result|
        expect(result).to be_a(Lutaml::UmlRepository::SearchResult)
        expect(result.element).to be_a(Lutaml::Uml::Class)
        expect(result.element.name).to match(/.*Type/)
      end
      # ClassificationType and RequirementType
      expect(results.count).to eq(2)
    end

    it "returns empty array when no matches" do
      results = query.search_classes("NonExistentPattern")
      expect(results).to eq([])
    end

    it "handles case-sensitive search" do
      results = query.search_classes("requirement", case_sensitive: true)
      expect(results).to be_an(Array)
      expect(results.empty?).to eq(true)
    end

    it "handles case-insensitive search" do
      results = query.search_classes("requirement", case_sensitive: false)
      expect(results).to be_an(Array)
      expect(results.empty?).to eq(false)
    end
  end

  describe "#search_packages" do
    it "searches packages by path pattern" do
      results = query.search_packages("*")

      expect(results).to be_an(Array)
      results.each do |result|
        expect(result).to be_a(Lutaml::UmlRepository::SearchResult)
        expect(result.element).to be_a(Lutaml::Uml::Package).or be_a(Lutaml::Uml::Document)
        expect(result.element_type).to eq("package")
        expect(result.match_field).to eq("package_path")
      end
      expect(results.count).to eq(2)

      expect(results[1].qualified_name)
        .to eq("ModelRoot::requirement type class diagram")
      expect(results[1].package_path)
        .to eq("ModelRoot::requirement type class diagram")
    end

    it "searches with glob patterns" do
      results = query.search_packages("ModelRoot*")

      expect(results).to be_an(Array)
      expect(results.count).to eq(2)
    end

    it "searches with regex patterns" do
      results = query.search_packages("ModelRoot.*")

      expect(results).to be_an(Array)
      expect(results.count).to eq(2)
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
        expect(results.count).to eq(1)

        results.each do |result|
          expect(result).to be_a(Lutaml::UmlRepository::SearchResult)
          expect(result.element).not_to be_nil
          expect(result.element_type).not_to be_nil
          expect(result.match_field).to eq("stereotype")
          expect(result.element.stereotype).to eq(stereotype)
        end
      end
    end

    it "handles wildcard patterns" do
      results = query.search_by_stereotype("*")

      expect(results).to be_an(Array)
      expect(results.count).to eq(3)
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
      expect(results.count).to eq(6)

      results.each do |result|
        expect(result).to be_a(Lutaml::UmlRepository::SearchResult)
        expect(result.element).to be_a(Lutaml::Uml::TopElementAttribute)
        expect(result.element_type).to eq("attribute")
      end

      expect(results[0].match_context).to eq(
        {
          "class_name" => "ClassificationType",
          "class_qname" => "ModelRoot::requirement type class " \
                           "diagram::ClassificationType",
        },
      )
      expect(results[0].match_field).to eq("name")
      expect(results[0].package_path)
        .to eq("ModelRoot::requirement type class diagram")
      expect(results[0].qualified_name)
        .to eq(
          "ModelRoot::requirement type class diagram::ClassificationType::value",
        )
    end

    it "finds attributes by name pattern" do
      results = query.search_attributes("id")

      expect(results).to be_an(Array)
      expect(results.count).to eq(1)

      expect(results[0].element.name).to eq("id")
      expect(results[0].element).to be_a(Lutaml::Uml::TopElementAttribute)
    end

    it "returns empty array when no matches" do
      results = query.search_attributes("NonExistentAttribute")
      expect(results).to eq([])
    end
  end

  describe "#search_associations" do
    it "searches associations across all classes" do
      results = query.search_associations("*")

      expect(results).to be_an(Array)
      expect(results.count).to eq(9)

      expect(results[0]).to be_a(Lutaml::UmlRepository::SearchResult)
      expect(results[0].element).to be_a(Lutaml::Uml::Association)
      expect(results[0].element_type).to eq("association")
      expect(results[0].qualified_name).to eq("(unnamed)")
      expect(results[0].package_path).to eq("")
      expect(results[0].match_field).to eq("member_end_attribute_name")
      expect(results[0].match_context).to eq(
        {
          "source" => "BibliographicItem",
          "target" => "RequirementType",
        },
      )
    end

    it "searches associations by exact match" do
      results = query.search_associations("ClassificationType")

      expect(results).to be_an(Array)
      expect(results.count).to eq(2)
    end

    it "finds associations by glob pattern" do
      results = query.search_associations("*Item")

      expect(results).to be_an(Array)
      expect(results.count).to eq(2)
      results.each do |result|
        expect(result).to be_a(Lutaml::UmlRepository::SearchResult)
        expect(result.element).to be_a(Lutaml::Uml::Association)
      end
    end

    it "returns empty array when no matches" do
      results = query.search_associations("NonExistentAttribute")
      expect(results).to eq([])
    end
  end

  describe "#full_text_search" do
    it "searches across all text fields" do
      results = query.full_text_search("requirement")
      expect(results).to be_a(Hash)
      expect(results).to have_key(:classes)
      expect(results).to have_key(:packages)
      expect(results).to have_key(:total)
      expect(results[:classes].size).to eq(3)
      expect(results[:packages].size).to eq(1)
      expect(results[:total]).to eq(4)

      expect(results[:classes][0]).to be_a(Lutaml::UmlRepository::SearchResult)
      expect(results[:classes][0].element)
        .to be_a(Lutaml::Uml::Class)
      expect(results[:packages][0]).to be_a(Lutaml::UmlRepository::SearchResult)
      expect(results[:packages][0].element)
        .to be_a(Lutaml::Uml::Package)
    end

    it "searches in class names" do
      results = query.full_text_search("Requirement")
      expect(results[:classes]).to be_an(Array)
      expect(results[:classes].size).to eq(3)
    end

    it "searches in package names" do
      results = query.full_text_search("Model")
      expect(results[:packages]).to be_an(Array)
      expect(results[:packages].size).to eq(2)
    end

    it "returns empty results when no matches" do
      results = query.full_text_search("XyzNonExistent123")
      expect(results[:classes]).to eq([])
      expect(results[:packages]).to eq([])
      expect(results[:total]).to eq(0)
    end

    it "handles case-sensitive search" do
      results = query.full_text_search("requirement", case_sensitive: true)
      expect(results).to be_a(Hash)
      expect(results[:classes].size).to eq(0)
    end
  end

  describe "with simple document" do
    let(:document) { create_simple_test_document }

    it "searches for test class" do
      results = query.search_classes("TestClass")
      expect(results.length).to eq(1)
      expect(results[0]).to be_a(Lutaml::UmlRepository::SearchResult)
      expect(results[0].element).to be_a(Lutaml::Uml::Class)
      expect(results[0].element.name).to eq("TestClass")
    end

    it "searches for test package" do
      results = query.search_packages("*::RootPackage")
      expect(results.length).to eq(2)
      expect(results[0]).to be_a(Lutaml::UmlRepository::SearchResult)
      expect(results[0].element).to be_a(Lutaml::Uml::Package)
      expect(results[0].element.name).to eq("RootPackage")
    end

    it "searches by test stereotype" do
      results = query.search_by_stereotype("TestStereotype")
      expect(results.length).to eq(1)
      expect(results[0]).to be_a(Lutaml::UmlRepository::SearchResult)
      expect(results[0].element).to be_a(Lutaml::Uml::Class)
      expect(results[0].element.name).to eq("TestClass")
    end

    it "performs full text search" do
      results = query.full_text_search("Test")
      expect(results[:classes]).not_to be_empty
      expect(results[:packages]).to be_empty
    end
  end
end
