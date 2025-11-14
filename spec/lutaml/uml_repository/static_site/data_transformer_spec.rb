# frozen_string_literal: true

require "spec_helper"
require "lutaml/uml_repository/static_site/data_transformer"

RSpec.describe Lutaml::UmlRepository::StaticSite::DataTransformer do
  let(:test_package) do
    double("Package").tap do |pkg|
      allow(pkg).to receive(:xmi_id).and_return("pkg_001")
      allow(pkg).to receive(:name).and_return("TestPackage")
      allow(pkg).to receive(:definition).and_return("Test package description")
      allow(pkg).to receive(:stereotypes).and_return(["ApplicationSchema"])
      allow(pkg).to receive(:owner).and_return(nil)
      allow(pkg).to receive(:packages).and_return([])
      allow(pkg).to receive(:classes) { [test_class] }
      allow(pkg).to receive(:is_a?) do |klass|
        klass == Lutaml::Uml::Package
      end
    end
  end

  let(:test_class) do
    double("Class").tap do |cls|
      allow(cls).to receive(:xmi_id).and_return("cls_001")
      allow(cls).to receive(:name).and_return("TestClass")
      allow(cls).to receive(:definition).and_return("Test class description")
      allow(cls).to receive(:stereotypes).and_return(["FeatureType"])
      allow(cls).to receive(:owner) { test_package }
      allow(cls).to receive(:attributes).and_return([test_attribute])
      allow(cls).to receive(:operations).and_return(nil)
      allow(cls).to receive(:is_abstract).and_return(false)
      allow(cls).to receive(:class).and_return(Lutaml::Uml::TopElement)
      allow(cls).to receive(:is_a?) do |klass|
        klass == Lutaml::Uml::TopElement
      end
    end
  end

  let(:repository) do
    double("UmlRepository").tap do |repo|
      allow(repo).to receive(:packages_index) { [test_package] }
      allow(repo).to receive(:classes_index) { [test_class] }
      allow(repo).to receive(:associations_index) { [test_association] }
      allow(repo).to receive(:diagrams_in_package).and_return([])
      allow(repo).to receive(:diagrams_index).and_return([])
      allow(repo).to receive(:associations_of).and_return([])
      allow(repo).to receive(:supertype_of).and_return(nil)
      allow(repo).to receive(:subtypes_of).and_return([])
    end
  end

  let(:test_attribute) do
    double("Attribute",
           name: "testAttr",
           type: "String",
           visibility: "public",
           definition: "Test attribute",
           stereotypes: [],
           cardinality: double("Cardinality", min: 1, max: 1),
           is_static: false,
           is_read_only: false,
           default: nil,)
  end

  let(:test_association) do
    double("Association",
           xmi_id: "assoc_001",
           name: "testAssociation",
           member_end: [
             double("End1",
                    type: test_class,
                    name: "end1",
                    cardinality: double("Card", min: 1, max: 1),
                    navigable?: true,
                    aggregation: "none",
                    visibility: "public",),
             double("End2",
                    type: test_class,
                    name: "end2",
                    cardinality: double("Card", min: 0, max: -1),
                    navigable?: true,
                    aggregation: "composite",
                    visibility: "public",),
           ],)
  end

  let(:transformer) { described_class.new(repository) }

  describe "#initialize" do
    it "initializes with repository and default options" do
      expect(transformer.repository).to eq(repository)
      expect(transformer.options).to be_a(Hash)
    end

    it "merges provided options with defaults" do
      custom_transformer = described_class.new(repository,
                                               include_diagrams: false,
                                               max_definition_length: 100,)

      expect(custom_transformer.options[:include_diagrams]).to be false
      expect(custom_transformer.options[:max_definition_length]).to eq(100)
    end

    it "creates an IDGenerator instance" do
      expect(transformer.id_generator).to be_a(Lutaml::UmlRepository::StaticSite::IDGenerator)
    end
  end

  describe "#transform" do
    before do
      # Allow repository queries
      allow(repository).to receive(:associations_of).and_return([])
      allow(repository).to receive(:supertype_of).and_return(nil)
      allow(repository).to receive(:subtypes_of).and_return([])
      allow(repository).to receive(:diagrams_in_package).and_return([])
      allow(repository).to receive(:diagrams_index).and_return([])
    end

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
      expect(result[:metadata][:generator]).to eq("LutaML Static Site Generator")
    end

    it "builds statistics" do
      result = transformer.transform
      stats = result[:metadata][:statistics]

      expect(stats).to include(:packages, :classes, :associations, :attributes)
      expect(stats[:packages]).to eq(1)
      expect(stats[:classes]).to eq(1)
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
      expect(cls).to include(:id, :xmiId, :name, :qualifiedName, :type,
                             :package)
    end

    it "builds attributes map" do
      result = transformer.transform
      attributes = result[:attributes]

      expect(attributes).to be_a(Hash)
      expect(attributes).not_to be_empty

      # Check first attribute structure
      attr = attributes.values.first
      expect(attr).to include(:id, :name, :type, :visibility, :owner,
                              :cardinality)
    end

    it "builds associations map" do
      result = transformer.transform
      associations = result[:associations]

      expect(associations).to be_a(Hash)
      expect(associations).not_to be_empty

      # Check first association structure
      assoc = associations.values.first
      expect(assoc).to include(:id, :xmiId, :name, :type, :source, :target)
    end

    it "builds operations map" do
      result = transformer.transform
      operations = result[:operations]

      expect(operations).to be_a(Hash)
      # Should be empty since test_class has no operations
      expect(operations).to be_empty
    end

    it "builds diagrams map when enabled" do
      result = transformer.transform
      diagrams = result[:diagrams]

      expect(diagrams).to be_a(Hash)
    end

    it "excludes diagrams when disabled" do
      custom_transformer = described_class.new(repository,
                                               include_diagrams: false)
      allow(repository).to receive(:associations_of).and_return([])
      allow(repository).to receive(:supertype_of).and_return(nil)
      allow(repository).to receive(:subtypes_of).and_return([])

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
      pkg = result[:packages].values.first

      expect(pkg[:definition]).to eq("Test package description")
    end

    it "truncates long definitions when max_definition_length is set" do
      custom_transformer = described_class.new(repository,
                                               max_definition_length: 10)
      allow(repository).to receive(:associations_of).and_return([])
      allow(repository).to receive(:supertype_of).and_return(nil)
      allow(repository).to receive(:subtypes_of).and_return([])
      allow(repository).to receive(:diagrams_in_package).and_return([])
      allow(repository).to receive(:diagrams_index).and_return([])

      result = custom_transformer.transform
      pkg = result[:packages].values.first

      expect(pkg[:definition].length).to be <= 13 # 10 + "..."
    end

    it "builds qualified names correctly" do
      result = transformer.transform
      cls = result[:classes].values.first

      expect(cls[:qualifiedName]).to include("TestPackage", "TestClass")
    end

    it "serializes cardinality correctly" do
      result = transformer.transform
      attr = result[:attributes].values.first

      expect(attr[:cardinality]).to include(:min, :max)
      expect(attr[:cardinality][:min]).to eq(1)
      expect(attr[:cardinality][:max]).to eq(1)
    end

    it "serializes association ends correctly" do
      result = transformer.transform
      assoc = result[:associations].values.first

      expect(assoc[:source]).to include(:class, :className, :role,
                                        :cardinality, :navigable, :aggregation)
      expect(assoc[:target]).to include(:class, :className, :role,
                                        :cardinality, :navigable, :aggregation)
    end
  end
end
