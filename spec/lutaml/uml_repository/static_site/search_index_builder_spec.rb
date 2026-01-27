# frozen_string_literal: true

require "spec_helper"
require_relative "../../../../lib/lutaml/uml_repository/" \
                 "static_site/search_index_builder"

RSpec.describe Lutaml::UmlRepository::StaticSite::SearchIndexBuilder do
  let(:repository) do
    double("UmlRepository",
      packages_index: [test_package],
      classes_index: [test_class],
      associations_index: [test_association],
    )
  end

  let(:test_package) do
    double("Package",
      xmi_id: "pkg_001",
      name: "TestPackage",
      definition: "Test package for search indexing",
      stereotypes: ["ApplicationSchema"],
      owner: nil,
    )
  end

  let(:test_class) do
    double("Class",
      xmi_id: "cls_001",
      name: "Building",
      definition: "A building class in urban planning",
      stereotypes: ["FeatureType"],
      owner: test_package,
      attributes: [test_attribute],
      operations: [],
      class: Lutaml::Uml::TopElement,
    )
  end

  let(:test_attribute) do
    double("Attribute",
      name: "buildingID",
      type: "String",
      definition: "Unique identifier for building",
      stereotypes: [],
    )
  end

  let(:test_association) do
    double("Association",
      xmi_id: "assoc_001",
      name: "contains",
      owner_end: "Building",
      member_end: "BuildingPart",
    )
  end

  let(:builder) { described_class.new(repository) }

  describe "#initialize" do
    it "initializes with repository and default options" do
      expect(builder.repository).to eq(repository)
      expect(builder.options).to be_a(Hash)
    end

    it "creates an IDGenerator instance" do
      expect(builder.id_generator).to be_a(Lutaml::UmlRepository::StaticSite::IDGenerator)
    end
  end

  describe "#build" do
    it "returns lunr.js-compatible search index structure" do
      index = builder.build

      expect(index).to be_a(Hash)
      expect(index).to include(
        :version, :fields, :ref, :documentStore, :pipeline
      )
    end

    it "includes version information" do
      index = builder.build
      expect(index[:version]).to eq("1.0.0")
    end

    it "defines searchable fields with boost values" do
      index = builder.build
      fields = index[:fields]

      expect(fields).to be_an(Array)
      expect(fields).not_to be_empty

      # Check for expected fields
      name_field = fields.find { |f| f[:name] == "name" }
      expect(name_field).not_to be_nil
      expect(name_field[:boost]).to eq(10)
    end

    it "uses 'id' as reference field" do
      index = builder.build
      expect(index[:ref]).to eq("id")
    end

    it "builds document store with all entity types" do
      index = builder.build
      docs = index[:documentStore]

      expect(docs).to be_an(Array)
      expect(docs).not_to be_empty

      # Should include documents for different types
      types = docs.map { |d| d[:type] }.uniq
      expect(types).to include("class", "attribute", "package")
    end

    it "includes pipeline configuration" do
      index = builder.build
      pipeline = index[:pipeline]

      expect(pipeline).to include("stemmer", "stopWordFilter")
    end
  end

  describe "document building" do
    let(:index) { builder.build }
    let(:documents) { index[:documentStore] }

    it "creates documents for classes" do
      class_docs = documents.select { |d| d[:type] == "class" }

      expect(class_docs).not_to be_empty

      doc = class_docs.first
      expect(doc).to include(
        :id, :type, :entityType, :entityId, :name,
        :qualifiedName, :package, :content, :boost
      )
      expect(doc[:type]).to eq("class")
      expect(doc[:boost]).to eq(1.5)  # Classes have higher boost
    end

    it "creates documents for attributes" do
      attr_docs = documents.select { |d| d[:type] == "attribute" }

      expect(attr_docs).not_to be_empty

      doc = attr_docs.first
      expect(doc).to include(:id, :type, :name, :ownerName, :ownerId)
      expect(doc[:boost]).to eq(1.0)
    end

    it "creates documents for

 associations" do
      assoc_docs = documents.select { |d| d[:type] == "association" }

      expect(assoc_docs).not_to be_empty

      doc = assoc_docs.first
      expect(doc[:boost]).to eq(0.8)  # Associations have lower boost
    end

    it "creates documents for packages" do
      pkg_docs = documents.select { |d| d[:type] == "package" }

      expect(pkg_docs).not_to be_empty

      doc = pkg_docs.first
      expect(doc[:boost]).to eq(1.2)
    end

    it "builds searchable content for each document" do
      doc = documents.first

      expect(doc[:content]).to be_a(String)
      expect(doc[:content]).not_to be_empty
      # Normalized to lowercase
      expect(doc[:content]).to eq(doc[:content].downcase)
    end

    it "includes entity metadata in documents" do
      class_doc = documents.find { |d| d[:type] == "class" }

      expect(class_doc[:entityId]).to be_a(String)
      expect(class_doc[:entityType]).to be_a(String)
      expect(class_doc[:qualifiedName]).to be_a(String)
    end
  end

  describe "content normalization" do
    it "normalizes content to lowercase" do
      # Use send to test private method if needed, or test through public
      # interface
      class_docs = builder.build[:documentStore].select do |d|
        d[:type] == "class"
      end

      class_docs.each do |doc|
        expect(doc[:content]).to eq(doc[:content].downcase)
      end
    end

    it "removes extra whitespace from content" do
      class_docs = builder.build[:documentStore].select do |d|
        d[:type] == "class"
      end

      class_docs.each do |doc|
        expect(doc[:content]).not_to match(/\s{2,}/) # No multiple spaces
      end
    end
  end

  describe "options handling" do
    it "respects custom options" do
      custom_builder = described_class.new(repository, languages: ["en", "ja"])

      expect(custom_builder.options[:languages]).to eq(["en", "ja"])
    end
  end

  describe "error handling" do
    it "handles missing attributes gracefully" do
      class_without_attrs = double("Class",
        xmi_id: "cls_002",
        name: "NoAttrs",
        definition: nil,
        stereotypes: nil,
        owner: test_package,
        attributes: nil,
        operations: nil,
        class: Lutaml::Uml::TopElement,
      )

      repo_with_minimal = double("Repository",
        packages_index: [],
        classes_index: [class_without_attrs],
        associations_index: [],
      )

      minimal_builder = described_class.new(repo_with_minimal)

      expect { minimal_builder.build }.not_to raise_error
    end

    it "handles nil definitions" do
      expect { builder.build }.not_to raise_error
    end
  end

  describe "performance" do
    it "handles large repositories efficiently" do
      # Create a larger repository
      large_classes = Array.new(100) do |i|
        double("Class#{i}",
          xmi_id: "cls_#{i}",
          name: "Class#{i}",
          definition: "Description #{i}",
          stereotypes: [],
          owner: test_package,
          attributes: [],
          operations: nil,
          class: Lutaml::Uml::TopElement,
        )
      end

      large_repo = double("LargeRepository",
        packages_index: [test_package],
        classes_index: large_classes,
        associations_index: [],
      )

      large_builder = described_class.new(large_repo)

      start_time = Time.now
      index = large_builder.build
      duration = Time.now - start_time

      expect(duration).to be < 1.0 # Should complete in under 1 second
      expect(index[:documentStore].size).to be >= 100
    end
  end
end
