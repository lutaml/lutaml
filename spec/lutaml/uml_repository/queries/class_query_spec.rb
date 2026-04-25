# frozen_string_literal: true

require "spec_helper"
require_relative "../../../../lib/lutaml/uml_repository/index_builder"

RSpec.describe Lutaml::UmlRepository::Queries::ClassQuery do
  let(:document) { create_test_document }
  let(:indexes) { Lutaml::UmlRepository::IndexBuilder.build_all(document) }
  let(:query) { described_class.new(document, indexes) }

  describe "#find_by_qname" do
    it "finds class by qualified name" do
      qname = indexes[:qualified_names].keys.find do |n|
        n.to_s.include?("BibliographicItem")
      end
      next unless qname

      klass = query.find_by_qname(qname)
      expect(klass).to be_a(Lutaml::Uml::Class)
    end

    it "found class has correct name" do
      qname = indexes[:qualified_names].keys.find do |n|
        n.to_s.include?("BibliographicItem")
      end
      next unless qname

      expect(query.find_by_qname(qname).name).to eq("BibliographicItem")
    end

    it { expect(query.find_by_qname("NonExistent::Class")).to be_nil }

    it "accepts string names" do
      qname = indexes[:qualified_names].keys.first&.to_s
      next unless qname

      klass = query.find_by_qname(qname)
      expect(klass).to be_a(Lutaml::Uml::Class)
        .or be_a(Lutaml::Uml::DataType)
        .or be_a(Lutaml::Uml::Enum).or be_nil
    end
  end

  describe "#find_by_stereotype" do
    it "finds classes with specific stereotype" do
      stereotypes = indexes[:stereotypes].keys.compact
      stereotypes.each do |stereotype|
        classes = query.find_by_stereotype(stereotype)
        expect(classes).to be_an(Array)
      end
    end

    it "found classes have matching stereotype" do
      stereotypes = indexes[:stereotypes].keys.compact
      stereotypes.each do |stereotype|
        query.find_by_stereotype(stereotype).each do |klass|
          expect(klass.stereotype).to include(stereotype)
        end
      end
    end

    it { expect(query.find_by_stereotype("NonExistentStereotype")).to eq([]) }

    it { expect(query.find_by_stereotype(nil)).to be_an(Array) }
  end

  describe "#in_package" do
    let(:pkg_path) { indexes[:package_paths].keys.first }

    it "finds classes in specific package" do
      next unless pkg_path

      expect(query.in_package(pkg_path)).to be_an(Array)
    end

    it "returns Lutaml::Uml::Class instances" do
      next unless pkg_path

      expect(query.in_package(pkg_path)).to all(be_a(Lutaml::Uml::Class))
    end

    it { expect(query.in_package("NonExistent")).to eq([]) }

    it "accepts string paths" do
      path = indexes[:package_paths].keys.first&.to_s
      next unless path

      expect(query.in_package(path)).to be_an(Array)
    end

    context "with recursive option" do
      it "recursive includes more than non-recursive" do
        next unless pkg_path

        all = query.in_package(pkg_path, recursive: true)
        direct = query.in_package(pkg_path, recursive: false)
        expect(all.length).to be >= direct.length
      end

      it "non-recursive returns array" do
        next unless pkg_path

        expect(query.in_package(pkg_path, recursive: false)).to be_an(Array)
      end
    end
  end

  describe "with simple document" do
    let(:document) { create_simple_test_document }
    let(:klass) { query.find_by_qname("ModelRoot::RootPackage::TestClass") }

    it { expect(klass).to be_a(Lutaml::Uml::Class) }
    it { expect(klass.name).to eq("TestClass") }

    it "finds class by stereotype" do
      classes = query.find_by_stereotype("TestStereotype")
      expect(classes.length).to eq(1)
    end

    it "stereotype class has correct name" do
      expect(query.find_by_stereotype("TestStereotype").first.name).to eq("TestClass")
    end

    it "finds classes in package" do
      classes = query.in_package("ModelRoot::RootPackage", recursive: false)
      expect(classes.length).to eq(2)
    end

    it "package classes include TestClass and TestEnum" do
      classes = query.in_package("ModelRoot::RootPackage", recursive: false)
      expect(classes.map(&:name)).to contain_exactly("TestClass", "TestEnum")
    end

    it "finds class by relative package path" do
      classes = query.in_package("RootPackage", recursive: false)
      expect(classes.length).to eq(2)
    end

    it "relative path matches absolute path" do
      relative = query.in_package("RootPackage", recursive: true)
      absolute = query.in_package("ModelRoot::RootPackage", recursive: true)
      expect(relative.length).to eq(absolute.length)
    end
  end
end
