# frozen_string_literal: true

require "spec_helper"
require_relative "../../../../lib/lutaml/uml_repository/" \
                 "static_site/data_transformer"

RSpec.describe Lutaml::UmlRepository::StaticSite::DataTransformer do
  let(:document) { create_simple_test_document }
  let(:repository) { Lutaml::UmlRepository::Repository.new(document: document) }
  let(:transformer) { described_class.new(repository) }

  describe "#initialize" do
    it "initializes with repository and default options", :aggregate_failures do
      expect(transformer.repository).to eq(repository)
      expect(transformer.options).to be_a(Hash)
    end

    it "merges provided options with defaults", :aggregate_failures do
      custom_transformer = described_class.new(repository,
                                               include_diagrams: false,
                                               max_definition_length: 100)

      expect(custom_transformer.options[:include_diagrams]).to be false
      expect(custom_transformer.options[:max_definition_length]).to eq(100)
    end

    it "creates an IDGenerator instance" do
      expect(transformer.id_generator).to be_a(Lutaml::UmlRepository::StaticSite::IdGenerator)
    end
  end

  describe "#transform" do
    it "returns a SpaDocument with all expected sections",
       :aggregate_failures do
      result = transformer.transform

      expect(result).to be_a(Lutaml::UmlRepository::StaticSite::Models::SpaDocument)
      expect(result.metadata).to be_a(Lutaml::UmlRepository::StaticSite::Models::SpaMetadata)
      expect(result.package_tree).to be_a(Lutaml::UmlRepository::StaticSite::Models::SpaPackageTreeNode)
      expect(result.packages).to be_a(Hash)
      expect(result.classes).to be_a(Hash)
      expect(result.attributes).to be_a(Hash)
      expect(result.associations).to be_a(Hash)
      expect(result.operations).to be_a(Hash)
      expect(result.diagrams).to be_a(Hash)
    end

    it "builds metadata section", :aggregate_failures do
      result = transformer.transform

      expect(result.metadata.generated).to be_a(String)
      expect(result.metadata.generator).to eq("lutaml v#{Lutaml::VERSION}")
    end

    it "builds statistics", :aggregate_failures do
      result = transformer.transform
      stats = result.metadata.statistics

      expect(stats.packages).to be >= 1
      expect(stats.classes).to be >= 1
    end

    it "builds hierarchical package tree", :aggregate_failures do
      result = transformer.transform
      tree = result.package_tree

      expect(tree).to be_a(Lutaml::UmlRepository::StaticSite::Models::SpaPackageTreeNode)
      expect(tree.id).to be_a(String)
      expect(tree.name).to be_a(String)
      expect(tree.path).to be_a(String)
    end

    it "builds packages map with stable IDs", :aggregate_failures do
      result = transformer.transform
      packages = result.packages

      expect(packages).not_to be_empty

      pkg = packages.values.first
      expect(pkg).to be_a(Lutaml::UmlRepository::StaticSite::Models::SpaPackage)
      expect(pkg.id).not_to be_nil
      expect(pkg.name).not_to be_nil
    end

    it "builds classes map", :aggregate_failures do
      result = transformer.transform
      classes = result.classes

      expect(classes).not_to be_empty

      cls = classes.values.first
      expect(cls).to be_a(Lutaml::UmlRepository::StaticSite::Models::SpaClass)
      expect(cls.id).not_to be_nil
      expect(cls.name).not_to be_nil
      expect(cls.qualified_name).to be_a(String)
    end

    it "builds attributes map" do
      result = transformer.transform
      expect(result.attributes).to be_a(Hash)
    end

    it "builds associations map" do
      result = transformer.transform
      expect(result.associations).to be_a(Hash)
    end

    it "builds operations map" do
      result = transformer.transform
      expect(result.operations).to be_a(Hash)
    end

    it "builds diagrams map when enabled" do
      result = transformer.transform
      expect(result.diagrams).to be_a(Hash)
    end

    it "excludes diagrams when disabled" do
      custom_transformer = described_class.new(repository,
                                               include_diagrams: false)

      result = custom_transformer.transform

      expect(result.diagrams).to eq({})
    end
  end

  describe "ID generation" do
    it "generates stable IDs for packages" do
      result1 = transformer.transform
      result2 = transformer.transform

      expect(result1.packages.keys).to eq(result2.packages.keys)
    end

    it "generates stable IDs for classes" do
      result1 = transformer.transform
      result2 = transformer.transform

      expect(result1.classes.keys).to eq(result2.classes.keys)
    end

    it "generates stable IDs for attributes" do
      result1 = transformer.transform
      result2 = transformer.transform

      expect(result1.attributes.keys).to eq(result2.attributes.keys)
    end
  end

  describe "helper methods" do
    it "formats definitions properly" do
      result = transformer.transform
      expect(result).to be_a(Lutaml::UmlRepository::StaticSite::Models::SpaDocument)
    end

    it "truncates long definitions when max_definition_length is set" do
      custom_transformer = described_class.new(repository,
                                               max_definition_length: 10)

      result = custom_transformer.transform
      expect(result).to be_a(Lutaml::UmlRepository::StaticSite::Models::SpaDocument)
    end

    it "builds qualified names correctly" do
      result = transformer.transform

      result.classes.each_value do |cls|
        expect(cls.qualified_name).to be_a(String)
      end
    end

    it "serializes cardinality correctly" do
      result = transformer.transform
      expect(result).to be_a(Lutaml::UmlRepository::StaticSite::Models::SpaDocument)
    end

    it "serializes association ends correctly" do
      result = transformer.transform
      expect(result).to be_a(Lutaml::UmlRepository::StaticSite::Models::SpaDocument)
    end
  end

  describe "attribute typeRef precompute" do
    let(:document) { create_resolution_test_document }

    def attr_named(result, name)
      result.attributes.values.find { |attribute| attribute.name == name }
    end

    it "precomputes a deterministic typeRef for class-typed attributes",
       :aggregate_failures do
      result = transformer.transform
      expect(attr_named(result, "refSame").type_ref.qualified_name)
        .to eq("ModelRoot::PkgA::Beta")
      expect(attr_named(result, "refCross").type_ref.qualified_name)
        .to eq("ModelRoot::PkgB::Gamma")
    end

    it "emits no typeRef for primitive or unresolved types",
       :aggregate_failures do
      result = transformer.transform
      expect(attr_named(result, "refPrimitive").type_ref).to be_nil
      expect(attr_named(result, "refUnresolved").type_ref).to be_nil
    end

    it "marks an ambiguous reference", :aggregate_failures do
      ambiguous = attr_named(transformer.transform, "refAmbiguous")
      expect(ambiguous.type_ref).not_to be_nil
      expect(ambiguous.type_ref.ambiguous).to be(true)
    end

    it "serializes the typeRef under camelCase JSON keys" do
      json = attr_named(transformer.transform, "refSame").to_json
      expect(json).to include("\"typeRef\"").and include("\"classId\"")
    end

    it "is deterministic across transforms" do
      first = attr_named(transformer.transform, "refSame").type_ref.class_id
      second = attr_named(described_class.new(repository).transform,
                          "refSame").type_ref.class_id
      expect(first).to eq(second)
    end
  end
end
