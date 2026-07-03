# frozen_string_literal: true

require "spec_helper"
require "lutaml/uml_repository/static_site/generator"
require "lutaml/uml_repository/static_site/output/multi_file_strategy"
require "tempfile"

RSpec.describe "SPA Generation Integration", type: :integration do
  let(:document) { create_simple_test_document }
  let(:repository) { Lutaml::UmlRepository::Repository.new(document: document) }

  describe "end-to-end SPA generation" do
    let(:output_dir) { Dir.mktmpdir }

    after do
      FileUtils.rm_rf(output_dir)
    end

    it "generates multi-file SPA with valid JSON data" do
      generator = Lutaml::UmlRepository::StaticSite::Generator.new(
        repository,
        mode: :multi_file,
        output: output_dir,
      )
      result = generator.generate

      expect(result).to eq(output_dir)
      expect(File.exist?(File.join(output_dir, "index.html"))).to be true
      expect(File.exist?(File.join(output_dir, "data",
                                   "model.json"))).to be true
      expect(File.exist?(File.join(output_dir, "data",
                                   "search.json"))).to be true

      # Verify model.json contains valid typed SpaDocument JSON
      model_json = JSON.parse(File.read(File.join(output_dir, "data",
                                                  "model.json")))
      expect(model_json["metadata"]).to include("generator" => "lutaml v#{Lutaml::VERSION}")
      expect(model_json["metadata"]["statistics"]).to include("packages",
                                                              "classes")
      expect(model_json["packageTree"]).to include("id", "name", "children")
      expect(model_json["packages"]).to be_a(Hash)
      expect(model_json["classes"]).to be_a(Hash)

      # Verify search.json contains valid SpaSearchIndex JSON
      search_json = JSON.parse(File.read(File.join(output_dir, "data",
                                                   "search.json")))
      expect(search_json["version"]).to eq("1.0.0")
      expect(search_json["documentStore"]).to be_a(Array)
      expect(search_json["documentStore"].size).to be > 0
    end

    it "generates with custom output strategy" do
      captured_doc = nil
      captured_idx = nil

      custom_strategy = Class.new(
        Lutaml::UmlRepository::StaticSite::Output::Strategy,
      ) do
        define_method(:render) do |doc, idx|
          captured_doc = doc
          captured_idx = idx
          output_path
        end
      end

      generator = Lutaml::UmlRepository::StaticSite::Generator.new(
        repository,
        output: "/tmp/test.html",
        output_strategy: custom_strategy,
      )
      result = generator.generate

      expect(result).to eq("/tmp/test.html")
    end
  end

  describe "DataTransformer integration" do
    it "produces a fully-typed SpaDocument from real repository" do
      transformer = Lutaml::UmlRepository::StaticSite::DataTransformer.new(repository)
      doc = transformer.transform

      expect(doc).to be_a(Lutaml::UmlRepository::StaticSite::Models::SpaDocument)
      expect(doc.metadata).to be_a(Lutaml::UmlRepository::StaticSite::Models::SpaMetadata)
      expect(doc.metadata.statistics).to be_a(Lutaml::UmlRepository::StaticSite::Models::SpaStatistics)
      expect(doc.package_tree).to be_a(Lutaml::UmlRepository::StaticSite::Models::SpaPackageTreeNode)

      expect(doc.packages).to be_a(Hash)
      doc.packages.each_value do |pkg|
        expect(pkg).to be_a(Lutaml::UmlRepository::StaticSite::Models::SpaPackage)
      end

      expect(doc.classes).to be_a(Hash)
      doc.classes.each_value do |cls|
        expect(cls).to be_a(Lutaml::UmlRepository::StaticSite::Models::SpaClass)
      end

      expect(doc.attributes).to be_a(Hash)
      doc.attributes.each_value do |attr|
        expect(attr).to be_a(Lutaml::UmlRepository::StaticSite::Models::SpaAttribute)
      end

      expect(doc.associations).to be_a(Hash)
      doc.associations.each_value do |assoc|
        expect(assoc).to be_a(Lutaml::UmlRepository::StaticSite::Models::SpaAssociation)
      end
    end

    it "round-trips SpaDocument through JSON serialization" do
      transformer = Lutaml::UmlRepository::StaticSite::DataTransformer.new(repository)
      doc = transformer.transform
      json = doc.to_json
      parsed = JSON.parse(json)

      expect(parsed["metadata"]["generator"]).to eq("lutaml v#{Lutaml::VERSION}")
      expect(parsed["classes"]).to be_a(Hash)
      expect(parsed["packages"]).to be_a(Hash)
    end
  end

  describe "SearchIndexBuilder integration" do
    it "produces typed SpaSearchIndex from real repository" do
      builder = Lutaml::UmlRepository::StaticSite::SearchIndexBuilder.new(repository)
      index = builder.build

      expect(index).to be_a(Lutaml::UmlRepository::StaticSite::Models::SpaSearchIndex)
      expect(index.document_store).not_to be_empty

      index.document_store.each do |entry|
        expect(entry).to be_a(Lutaml::UmlRepository::StaticSite::Models::SpaSearchEntry)
        expect(entry.id).to be_a(String)
        expect(entry.type).to be_a(String)
        expect(entry.name).to be_a(String)
      end
    end
  end
end
