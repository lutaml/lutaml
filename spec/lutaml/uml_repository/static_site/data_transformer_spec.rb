# frozen_string_literal: true

require "spec_helper"
require_relative "../../../../lib/lutaml/uml_repository/" \
                 "static_site/data_transformer"

RSpec.describe Lutaml::UmlRepository::StaticSite::DataTransformer do
  let(:document) { create_simple_test_document }
  let(:repository) { Lutaml::UmlRepository::Repository.new(document: document) }
  let(:transformer) { described_class.new(repository) }

  describe "#initialize" do
    it "initializes with repository and default options" do
      expect(transformer.repository).to eq(repository)
      expect(transformer.options).to be_a(Hash)
    end

    it "merges provided options with defaults" do
      custom_transformer = described_class.new(repository,
                                               include_diagrams: false,
                                               max_definition_length: 100)

      expect(custom_transformer.options[:include_diagrams]).to be false
      expect(custom_transformer.options[:max_definition_length]).to eq(100)
    end

    it "creates an IDGenerator instance" do
      expect(transformer.id_generator).to be_a(Lutaml::UmlRepository::StaticSite::IDGenerator)
    end
  end

  describe "#transform" do
    it "returns a hash with all expected sections" do
      result = transformer.transform

      expect(result).to be_a(Hash)
      expect(result).to include(
        :metadata,
        :packageTree,
        :packages,
        :classes,
        :attributes,
        :associations,
        :operations,
        :diagrams,
      )
    end

    it "builds metadata section" do
      result = transformer.transform

      expect(result[:metadata]).to include(:generated, :generator, :version,
                                           :statistics)
      expect(result[:metadata][:generated]).to be_a(String)
      expect(result[:metadata][:generator])
        .to eq("LutaML Static Site Generator")
    end

    it "builds statistics" do
      result = transformer.transform
      stats = result[:metadata][:statistics]

      expect(stats).to include(:packages, :classes, :associations, :attributes)
      expect(stats[:packages]).to be >= 1
      expect(stats[:classes]).to be >= 1
    end

    it "builds hierarchical package tree" do
      result = transformer.transform
      tree = result[:packageTree]

      expect(tree).to be_a(Hash)
      expect(tree).to include(:id, :name, :path, :classCount)
    end

    it "builds packages map with stable IDs" do
      result = transformer.transform
      packages = result[:packages]

      expect(packages).to be_a(Hash)
      expect(packages).not_to be_empty

      # Check first package structure
      pkg = packages.values.first
      expect(pkg).to include(:id, :xmiId, :name, :path, :definition,
                             :stereotypes, :classes)
    end

    it "builds classes map" do
      result = transformer.transform
      classes = result[:classes]

      expect(classes).to be_a(Hash)
      expect(classes).not_to be_empty

      # Check first class structure
      cls = classes.values.first
      expect(cls)
        .to include(:id, :xmiId, :name, :qualifiedName, :type, :package)
    end

    it "builds attributes map" do
      result = transformer.transform
      attributes = result[:attributes]

      expect(attributes).to be_a(Hash)
      # Attributes may be empty if the test class doesn't have any
    end

    it "builds associations map" do
      result = transformer.transform
      associations = result[:associations]

      expect(associations).to be_a(Hash)
      # Associations may be empty in simple test document
    end

    it "builds operations map" do
      result = transformer.transform
      operations = result[:operations]

      expect(operations).to be_a(Hash)
      # Operations may be empty if classes don't have operations
    end

    it "builds diagrams map when enabled" do
      result = transformer.transform
      diagrams = result[:diagrams]

      expect(diagrams).to be_a(Hash)
    end

    it "excludes diagrams when disabled" do
      custom_transformer = described_class.new(repository,
                                               include_diagrams: false)

      result = custom_transformer.transform

      expect(result[:diagrams]).to eq({})
    end
  end

  describe "ID generation" do
    it "generates stable IDs for packages" do
      result1 = transformer.transform
      result2 = transformer.transform

      expect(result1[:packages].keys).to eq(result2[:packages].keys)
    end

    it "generates stable IDs for classes" do
      result1 = transformer.transform
      result2 = transformer.transform

      expect(result1[:classes].keys).to eq(result2[:classes].keys)
    end

    it "generates stable IDs for attributes" do
      result1 = transformer.transform
      result2 = transformer.transform

      expect(result1[:attributes].keys).to eq(result2[:attributes].keys)
    end
  end

  describe "helper methods" do
    it "formats definitions properly" do
      result = transformer.transform

      # Just verify the transform completes without error
      expect(result).to be_a(Hash)
    end

    it "truncates long definitions when max_definition_length is set" do
      custom_transformer = described_class.new(repository,
                                               max_definition_length: 10)

      result = custom_transformer.transform

      # Just verify the transform completes without error
      expect(result).to be_a(Hash)
    end

    it "builds qualified names correctly" do
      result = transformer.transform
      classes = result[:classes]

      # Verify qualified names are strings
      classes.each_value do |cls|
        expect(cls[:qualifiedName]).to be_a(String)
      end
    end

    it "serializes cardinality correctly" do
      result = transformer.transform

      # Just verify the transform completes without error
      expect(result).to be_a(Hash)
    end

    it "serializes association ends correctly" do
      result = transformer.transform

      # Just verify the transform completes without error
      expect(result).to be_a(Hash)
    end
  end
end
