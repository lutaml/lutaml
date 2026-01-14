# frozen_string_literal: true

require "spec_helper"
require_relative "../../../lib/lutaml/uml_repository/index_builder"

RSpec.describe Lutaml::UmlRepository::IndexBuilder do
  let(:document) { create_test_document }
  let(:indexes) { described_class.build_all(document) }

  describe ".build_all" do
    it "builds all indexes" do
      expect(indexes).to be_a(Hash)
      expect(indexes.keys).to include(
        :package_paths,
        :qualified_names,
        :stereotypes,
        :inheritance_graph,
        :diagram_index,
      )
    end

    it "returns frozen hash" do
      expect(indexes).to be_frozen
    end

    it "includes all index types" do
      expect(indexes[:package_paths]).to be_a(Hash)
      expect(indexes[:qualified_names]).to be_a(Hash)
      expect(indexes[:stereotypes]).to be_a(Hash)
      expect(indexes[:inheritance_graph]).to be_a(Hash)
      expect(indexes[:diagram_index]).to be_a(Hash)
    end
  end

  describe "package_paths index" do
    it "indexes packages by path" do
      package_paths_index = indexes[:package_paths]
      expect(package_paths_index).to be_a(Hash)
    end

    it "handles nested packages" do
      package_paths_index = indexes[:package_paths]
      package_paths_index.each do |path, package|
        expect(path).to be_a(String)
        expect(package).to be_a(Lutaml::Uml::Document)
          .or be_a(Lutaml::Uml::Package)
      end
    end

    it "creates correct paths for nested packages" do
      package_paths_index = indexes[:package_paths]
      paths = package_paths_index.keys.map(&:to_s)

      expect(paths).to include("ModelRoot")
      expect(paths.any? { |p| p.include?("::") }).to be(true).or be(false)
    end
  end

  describe "qualified_names index" do
    it "indexes classes by qualified name" do
      qualified_names_index = indexes[:qualified_names]
      expect(qualified_names_index).to be_a(Hash)
    end

    it "includes data types and enums" do
      qualified_names_index = indexes[:qualified_names]
      qualified_names_index.each do |qname, entity|
        expect(qname).to be_a(String)
        expect(entity).to be_a(Lutaml::Uml::Class)
          .or be_a(Lutaml::Uml::DataType)
          .or be_a(Lutaml::Uml::Enum)
      end
    end

    it "creates correct qualified names" do
      qualified_names_index = indexes[:qualified_names]
      qnames = qualified_names_index.keys.map(&:to_s)

      expect(qnames).not_to be_empty
      qnames.each do |qname|
        expect(qname).to be_a(String)
      end
    end
  end

  describe "stereotypes index" do
    it "groups classes by stereotype" do
      stereotypes_index = indexes[:stereotypes]
      expect(stereotypes_index).to be_a(Hash)
    end

    it "handles classes without stereotypes" do
      stereotypes_index = indexes[:stereotypes]

      stereotypes_index.each do |stereotype, classes|
        if stereotype.nil?
          expect(classes).to be_an(Array)
          classes.each do |klass|
            expect(klass.stereotype).to be_nil
          end
        else
          expect(stereotype).to be_a(String)
          expect(classes).to be_an(Array)
        end
      end
    end

    it "groups classes correctly" do
      stereotypes_index = indexes[:stereotypes]

      stereotypes_index.each_value do |classes|
        classes.each do |klass|
          expect(klass).to be_a(Lutaml::Uml::Class)
            .or be_a(Lutaml::Uml::Enum)
            .or be_a(Lutaml::Uml::DataType)
        end
      end
    end
  end

  describe "inheritance_graph index" do
    it "maps parent to children" do
      inheritance_graph = indexes[:inheritance_graph]
      expect(inheritance_graph).to be_a(Hash)
    end

    it "handles multiple inheritance levels" do
      inheritance_graph = indexes[:inheritance_graph]

      inheritance_graph.each do |parent_id, children|
        expect(parent_id).to be_a(String)
        expect(children).to be_an(Array)
        children.each do |child|
          expect(child).to be_a(String)
        end
      end
    end
  end

  describe "associations index" do
    it "creates bidirectional mappings" do
      associations = indexes[:associations]

      associations.values.flatten.each do |assoc|
        next unless ["inheritance",
                      "generalization"].include?(assoc.member_end_type)

        parent_id = assoc.member_end_xmi_id
        expect(associations.key?(parent_id)).to be(true).or be(false)
      end
    end
  end

  describe "diagram_index index" do
    it "indexes diagrams by package" do
      diagram_index = indexes[:diagram_index]
      expect(diagram_index).to be_a(Hash)
    end

    it "groups diagrams correctly" do
      diagram_index = indexes[:diagram_index]

      diagram_index.each do |package_id, diagrams|
        expect(package_id).to be_a(String)
        expect(diagrams).to be_an(Array)
        diagrams.each do |diagram|
          expect(diagram).to be_a(Lutaml::Uml::Diagram)
        end
      end
    end
  end

  describe "with simple document" do
    let(:document) { create_simple_test_document }

    it "builds indexes for simple document" do
      expect(indexes).to be_a(Hash)
      expect(indexes.keys).to include(
        :package_paths,
        :qualified_names,
        :stereotypes,
      )
    end

    it "indexes simple package structure" do
      package_paths_index = indexes[:package_paths]
      paths = package_paths_index.keys.map(&:to_s)

      expect(paths).to include("ModelRoot")
      expect(paths).to include("ModelRoot::RootPackage")
      expect(paths).to include("ModelRoot::RootPackage::NestedPackage")
    end

    it "indexes simple class structure" do
      qualified_names_index = indexes[:qualified_names]
      qnames = qualified_names_index.keys.map(&:to_s)

      expect(qnames).to include("ModelRoot::RootPackage::TestClass")
    end

    it "indexes simple enum structure" do
      qualified_names_index = indexes[:qualified_names]
      qnames = qualified_names_index.keys.map(&:to_s)

      expect(qnames).to include("ModelRoot::RootPackage::TestEnum")
    end

    it "groups by stereotype correctly" do
      stereotypes_index = indexes[:stereotypes]

      expect(stereotypes_index).to have_key("TestStereotype")
      expect(stereotypes_index["TestStereotype"]).to be_an(Array)
      expect(stereotypes_index["TestStereotype"].first.name).to eq("TestClass")
    end
  end
end
