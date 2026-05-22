# frozen_string_literal: true

require "spec_helper"
require "lutaml/uml_repository/static_site/search_index_builder"

RSpec.describe Lutaml::UmlRepository::StaticSite::SearchIndexBuilder do
  let(:document) { create_simple_test_document }
  let(:repository) { Lutaml::UmlRepository::Repository.new(document: document) }
  let(:builder) { described_class.new(repository) }

  describe "#initialize" do
    it "initializes with repository and default options", :aggregate_failures do
      expect(builder.repository).to eq(repository)
      expect(builder.options).to be_a(Hash)
    end

    it "creates an IDGenerator instance" do
      expect(builder.id_generator).to be_a(Lutaml::UmlRepository::StaticSite::IdGenerator)
    end
  end

  describe "#build" do
    it "returns a SpaSearchIndex with all expected fields",
       :aggregate_failures do
      index = builder.build

      expect(index).to be_a(Lutaml::UmlRepository::StaticSite::Models::SpaSearchIndex)
      expect(index.version).to eq("1.0.0")
      expect(index.ref).to eq("id")
      expect(index.fields).not_to be_empty
      expect(index.document_store).not_to be_empty
      expect(index.pipeline).to include("stemmer", "stopWordFilter")
    end

    it "includes version information" do
      index = builder.build
      expect(index.version).to eq("1.0.0")
    end

    it "defines searchable fields with boost values", :aggregate_failures do
      index = builder.build
      fields = index.fields

      expect(fields).to be_an(Array)
      expect(fields).not_to be_empty

      name_field = fields.find { |f| f[:name] == "name" }
      expect(name_field).not_to be_nil
      expect(name_field[:boost]).to eq(10)
    end

    it "uses 'id' as reference field" do
      index = builder.build
      expect(index.ref).to eq("id")
    end

    it "builds document store with all entity types", :aggregate_failures do
      docs = builder.build.document_store

      expect(docs).to be_an(Array)
      expect(docs).not_to be_empty

      types = docs.map(&:type).uniq
      expect(types).to include("class", "package")
    end

    it "includes pipeline configuration" do
      pipeline = builder.build.pipeline
      expect(pipeline).to include("stemmer", "stopWordFilter")
    end
  end

  describe "document building" do
    let(:documents) { builder.build.document_store }

    it "creates documents for classes", :aggregate_failures do
      class_docs = documents.select { |d| d.type == "class" }

      expect(class_docs).not_to be_empty

      doc = class_docs.first
      expect(doc.type).to eq("class")
      expect(doc.boost).to eq(1.5)
    end

    it "creates documents for packages", :aggregate_failures do
      pkg_docs = documents.select { |d| d.type == "package" }

      expect(pkg_docs).not_to be_empty

      doc = pkg_docs.first
      expect(doc.boost).to eq(1.2)
    end

    it "builds searchable content for each document", :aggregate_failures do
      doc = documents.first

      content = doc.content
      expect(content).to be_a(String)
      expect(content).not_to be_empty
      expect(content).to eq(content.downcase)
    end

    it "includes entity metadata in documents", :aggregate_failures do
      class_doc = documents.find { |d| d.type == "class" }

      expect(class_doc.entity_id).to be_a(String)
      expect(class_doc.entity_type).to be_a(String)
      expect(class_doc.qualified_name).to be_a(String)
    end
  end

  describe "content normalization" do
    it "normalizes content to lowercase" do
      class_docs = builder.build.document_store.select do |d|
        d.type == "class"
      end

      class_docs.each do |doc|
        expect(doc.content).to eq(doc.content.downcase)
      end
    end

    it "removes extra whitespace from content" do
      class_docs = builder.build.document_store.select do |d|
        d.type == "class"
      end

      class_docs.each do |doc|
        expect(doc.content).not_to match(/\s{2,}/)
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
      doc = Lutaml::Uml::Document.new
      doc.name = "NoAttrs"
      pkg = Lutaml::Uml::Package.new
      pkg.name = "Pkg"
      pkg.xmi_id = "pkg_na"
      klass = Lutaml::Uml::Class.new
      klass.name = "NoAttrs"
      klass.xmi_id = "cls_na"
      pkg.classes << klass
      doc.packages << pkg

      minimal_repo = Lutaml::UmlRepository::Repository.new(document: doc)
      minimal_builder = described_class.new(minimal_repo)

      expect { minimal_builder.build }.not_to raise_error
    end
  end

  describe "performance" do
    it "handles large repositories efficiently" do
      doc = Lutaml::Uml::Document.new
      doc.name = "Large"

      pkg = Lutaml::Uml::Package.new
      pkg.name = "BigPkg"
      pkg.xmi_id = "pkg_big"

      100.times do |i|
        klass = Lutaml::Uml::Class.new
        klass.name = "Class#{i}"
        klass.xmi_id = "cls_#{i}"
        pkg.classes << klass
      end

      doc.packages << pkg
      large_repo = Lutaml::UmlRepository::Repository.new(document: doc)
      large_builder = described_class.new(large_repo)

      start_time = Time.now
      index = large_builder.build
      duration = Time.now - start_time

      aggregate_failures do
        expect(duration).to be < 1.0
        expect(index.document_store.size).to be >= 100
      end
    end
  end
end
