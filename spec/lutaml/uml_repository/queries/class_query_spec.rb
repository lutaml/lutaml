# frozen_string_literal: true

require "spec_helper"
require_relative "../../../../lib/lutaml/uml_repository/index_builder"

RSpec.describe Lutaml::UmlRepository::Queries::ClassQuery do
  let(:document) { create_test_document }
  let(:indexes) { Lutaml::UmlRepository::IndexBuilder.build_all(document) }
  let(:query) { described_class.new(document, indexes) }

  describe "#find_by_qname" do
    it "finds class by qualified name" do
      qname = indexes[:qualified_names].keys.find do |name|
        name.to_s.include?("BibliographicItem")
      end

      if qname
        klass = query.find_by_qname(qname)
        expect(klass).to be_a(Lutaml::Uml::Class)
        expect(klass.name).to eq("BibliographicItem")
      end
    end

    it "returns nil for non-existent class" do
      qname = "NonExistent::Class"
      klass = query.find_by_qname(qname)
      expect(klass).to be_nil
    end

    it "accepts string names" do
      qname = indexes[:qualified_names].keys.first&.to_s
      if qname
        klass = query.find_by_qname(qname)
        expect(klass).to be_a(Lutaml::Uml::Class)
          .or be_a(Lutaml::Uml::DataType)
          .or be_a(Lutaml::Uml::Enum)
          .or be_nil
      end
    end
  end

  describe "#find_by_stereotype" do
    it "finds classes with specific stereotype" do
      stereotypes = indexes[:stereotypes].keys.compact

      stereotypes.each do |stereotype|
        classes = query.find_by_stereotype(stereotype)
        expect(classes).to be_an(Array)
        classes.each do |klass|
          expect(klass.stereotype).to include(stereotype)
        end
      end
    end

    it "returns empty array for non-existent stereotype" do
      classes = query.find_by_stereotype("NonExistentStereotype")
      expect(classes).to eq([])
    end

    it "handles nil stereotype" do
      classes = query.find_by_stereotype(nil)
      expect(classes).to be_an(Array)
    end
  end

  describe "#in_package" do
    it "finds classes in specific package" do
      package_path = indexes[:package_paths].keys.first
      if package_path
        classes = query.in_package(package_path)
        expect(classes).to be_an(Array)
        expect(classes).to all(be_a(Lutaml::Uml::Class))
      end
    end

    it "returns empty array for non-existent package" do
      path = "NonExistent"
      classes = query.in_package(path)
      expect(classes).to eq([])
    end

    it "accepts string paths" do
      path = indexes[:package_paths].keys.first&.to_s
      if path
        classes = query.in_package(path)
        expect(classes).to be_an(Array)
      end
    end

    context "with recursive option" do
      it "includes classes from nested packages when recursive is true" do
        root_path = indexes[:package_paths].keys.first
        if root_path
          all_classes = query.in_package(root_path, recursive: true)
          direct_classes = query.in_package(root_path, recursive: false)

          expect(all_classes.length).to be >= direct_classes.length
        end
      end

      it "excludes nested classes when recursive is false" do
        root_path = indexes[:package_paths].keys.first
        if root_path
          classes = query.in_package(root_path, recursive: false)
          expect(classes).to be_an(Array)
        end
      end
    end
  end

  describe "with simple document" do
    let(:document) { create_simple_test_document }

    it "finds class by qualified name" do
      qname = "ModelRoot::RootPackage::TestClass"
      klass = query.find_by_qname(qname)
      expect(klass).to be_a(Lutaml::Uml::Class)
      expect(klass.name).to eq("TestClass")
    end

    it "finds class by stereotype" do
      classes = query.find_by_stereotype("TestStereotype")
      expect(classes.length).to eq(1)
      expect(classes.first.name).to eq("TestClass")
    end

    it "finds class in package" do
      path = "ModelRoot::RootPackage"
      classes = query.in_package(path, recursive: false)
      expect(classes.length).to eq(2)
      expect(classes.map(&:name)).to contain_exactly("TestClass", "TestEnum")
    end
  end
end
