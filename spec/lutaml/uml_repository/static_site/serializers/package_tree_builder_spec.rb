# frozen_string_literal: true

require "spec_helper"
require "lutaml/uml_repository"

RSpec.describe Lutaml::UmlRepository::StaticSite::Serializers::PackageTreeBuilder do
  let(:document) { create_simple_test_document }
  let(:repository) { Lutaml::UmlRepository::Repository.new(document: document) }
  let(:id_generator) { Lutaml::UmlRepository::StaticSite::IdGenerator.new }

  describe "#build with single root" do
    it "returns a single tree node for single root package" do
      builder = described_class.new(repository, id_generator)
      result = builder.build

      expect(result).to be_a(Lutaml::UmlRepository::StaticSite::Models::SpaPackageTreeNode)
      expect(result.name).to eq("RootPackage")
      expect(result.children.size).to eq(1)
    end

    it "includes class references" do
      builder = described_class.new(repository, id_generator)
      result = builder.build

      expect(result.classes.size).to be >= 1
      result.classes.each do |class_ref|
        expect(class_ref).to be_a(Lutaml::UmlRepository::StaticSite::Models::SpaTreeClassRef)
        expect(class_ref.name).to be_a(String)
      end
    end

    it "recursively includes child packages" do
      builder = described_class.new(repository, id_generator)
      result = builder.build

      child_node = result.children.first
      expect(child_node.name).to eq("NestedPackage")
      expect(child_node.class_count).to eq(0)
    end

    it "accumulates class count from children" do
      builder = described_class.new(repository, id_generator)
      result = builder.build

      expect(result.class_count).to be >= 1
    end
  end

  describe "#build with multiple roots" do
    let(:multi_doc) do
      doc = Lutaml::Uml::Document.new
      doc.name = "Multi"

      pkg1 = Lutaml::Uml::Package.new
      pkg1.name = "Root1"
      pkg1.xmi_id = "pkg_r1"

      pkg2 = Lutaml::Uml::Package.new
      pkg2.name = "Root2"
      pkg2.xmi_id = "pkg_r2"

      doc.packages << pkg1
      doc.packages << pkg2
      doc
    end

    let(:multi_repo) { Lutaml::UmlRepository::Repository.new(document: multi_doc) }

    it "creates virtual root for multiple root packages" do
      builder = described_class.new(multi_repo, id_generator)
      result = builder.build

      expect(result.id).to eq("root")
      expect(result.name).to eq("Model")
      expect(result.children.size).to eq(2)
    end
  end

  describe "#build with empty-name classes" do
    let(:filtered_doc) do
      doc = Lutaml::Uml::Document.new
      doc.name = "Filtered"

      pkg = Lutaml::Uml::Package.new
      pkg.name = "Pkg"
      pkg.xmi_id = "pkg_f"

      valid_class = Lutaml::Uml::Class.new
      valid_class.name = "Valid"
      valid_class.xmi_id = "cls_v"

      empty_class = Lutaml::Uml::Class.new
      empty_class.name = ""
      empty_class.xmi_id = "cls_e"

      nil_class = Lutaml::Uml::Class.new
      nil_class.name = nil
      nil_class.xmi_id = "cls_n"

      pkg.classes << valid_class
      pkg.classes << empty_class
      pkg.classes << nil_class
      doc.packages << pkg
      doc
    end

    let(:filtered_repo) { Lutaml::UmlRepository::Repository.new(document: filtered_doc) }

    it "filters out classes with empty or nil names" do
      builder = described_class.new(filtered_repo, id_generator)
      result = builder.build

      expect(result.classes.size).to eq(1)
      expect(result.classes.first.name).to eq("Valid")
    end
  end
end
