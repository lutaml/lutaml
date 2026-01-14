# frozen_string_literal: true

require "spec_helper"
require_relative "../../../../lib/lutaml/uml_repository/index_builder"

RSpec.describe Lutaml::UmlRepository::Queries::PackageQuery do
  let(:document) { create_test_document }
  let(:indexes) { Lutaml::UmlRepository::IndexBuilder.build_all(document) }
  let(:query) { described_class.new(document, indexes) }

  describe "#find_by_path" do
    it "finds package by exact path" do
      path = Lutaml::Uml::PackagePath
        .new("ModelRoot::requirement type class diagram")
      package = query.find_by_path(path)
      expect(package).to be_a(Lutaml::Uml::Package)
      expect(package.name).to eq("requirement type class diagram")
    end

    it "returns nil for non-existent path" do
      path = Lutaml::Uml::PackagePath.new("NonExistent::Package")
      package = query.find_by_path(path)
      expect(package).to be_nil
    end

    it "finds nested packages" do
      nested_paths = indexes[:package_paths].keys.select do |p|
        p.to_s.include?("::")
      end

      nested_paths.each do |path|
        package = query.find_by_path(path)
        expect(package).to be_a(Lutaml::Uml::Package)
      end
    end

    it "accepts string paths" do
      package = query.find_by_path("ModelRoot::requirement type class diagram")
      expect(package).to be_a(Lutaml::Uml::Package)
    end
  end

  describe "#list" do
    context "when not recursive" do
      it "lists direct children" do
        root_path = Lutaml::Uml::PackagePath.new("ModelRoot")
        children = query.list(root_path, recursive: false)
        expect(children).to be_an(Array)
        children.each do |pkg|
          expect(pkg).to be_a(Lutaml::Uml::Package)
        end
      end

      it "does not include nested children" do
        root_path = Lutaml::Uml::PackagePath.new("ModelRoot")
        root_package = query.find_by_path(root_path)

        if root_package
          children = query.list(root_path, recursive: false)
          expected_count = root_package.packages.length
          expect(children.length).to eq(expected_count)
        end
      end
    end

    context "when recursive" do
      it "lists all descendants" do
        root_path = Lutaml::Uml::PackagePath.new("ModelRoot")
        descendants = query.list(root_path, recursive: true)
        expect(descendants).to be_an(Array)
        descendants.each do |pkg|
          expect(pkg).to be_a(Lutaml::Uml::Package)
        end
      end

      it "includes nested descendants" do
        root_path = Lutaml::Uml::PackagePath.new("ModelRoot")
        descendants = query.list(root_path, recursive: true)
        direct_children = query.list(root_path, recursive: false)

        expect(descendants.length).to be >= direct_children.length
      end
    end

    it "returns empty array for non-existent package" do
      path = Lutaml::Uml::PackagePath.new("NonExistent")
      children = query.list(path)
      expect(children).to eq([])
    end

    it "accepts string paths" do
      children = query.list("ModelRoot")
      expect(children).to be_an(Array)
    end
  end

  describe "#tree" do
    it "builds hierarchical tree" do
      root_path = Lutaml::Uml::PackagePath.new("ModelRoot")
      tree = query.tree(root_path)

      expect(tree).to be_a(Hash)
      expect(tree).to have_key(:name)
      expect(tree).to have_key(:path)
      expect(tree).to have_key(:classes_count)
      expect(tree).to have_key(:diagrams_count)
      expect(tree).to have_key(:children)
      expect(tree[:path]).to be_a(String)
      expect(tree[:children]).to be_an(Array)
    end

    it "includes nested packages in tree" do
      root_path = Lutaml::Uml::PackagePath.new("ModelRoot")
      tree = query.tree(root_path)

      tree[:children].each do |child_tree|
        expect(child_tree).to be_a(Hash)
        expect(tree).to have_key(:name)
        expect(tree).to have_key(:path)
        expect(child_tree).to have_key(:children)
      end
    end

    context "with max_depth" do
      it "respects max_depth" do
        root_path = Lutaml::Uml::PackagePath.new("ModelRoot")
        tree = query.tree(root_path, max_depth: 1)

        expect(tree[:children]).to be_an(Array)
        tree[:children].each do |child|
          expect(child[:children]).to eq([])
        end
      end

      it "builds full tree when max_depth is nil" do
        root_path = Lutaml::Uml::PackagePath.new("ModelRoot")
        tree = query.tree(root_path, max_depth: nil)

        expect(tree[:children]).to be_an(Array)
      end
    end

    it "returns nil for non-existent package" do
      path = Lutaml::Uml::PackagePath.new("NonExistent")
      tree = query.tree(path)
      expect(tree).to be_nil
    end

    it "accepts string paths" do
      tree = query.tree("ModelRoot")
      expect(tree).to be_a(Hash).or be_nil
    end
  end

  describe "with simple document" do
    let(:document) { create_simple_test_document }

    it "finds root package" do
      path = Lutaml::Uml::PackagePath.new("ModelRoot::RootPackage")
      package = query.find_by_path(path)
      expect(package).to be_a(Lutaml::Uml::Package)
      expect(package.name).to eq("RootPackage")
    end

    it "finds nested package" do
      path = Lutaml::Uml::PackagePath.new("ModelRoot::RootPackage::NestedPackage")
      package = query.find_by_path(path)
      expect(package).to be_a(Lutaml::Uml::Package)
      expect(package.name).to eq("NestedPackage")
    end

    it "lists direct children correctly" do
      path = Lutaml::Uml::PackagePath.new("ModelRoot::RootPackage")
      children = query.list(path, recursive: false)
      expect(children.length).to eq(1)
      expect(children.first.name).to eq("NestedPackage")
    end

    it "builds correct tree structure" do
      path = Lutaml::Uml::PackagePath.new("ModelRoot::RootPackage")
      tree = query.tree(path)

      expect(tree[:name]).to eq("RootPackage")
      expect(tree[:children].length).to eq(1)
      expect(tree[:children].first[:name]).to eq("NestedPackage")
    end
  end
end
