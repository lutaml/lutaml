# frozen_string_literal: true

require "spec_helper"

RSpec.describe Lutaml::Uml::Association do
  describe "package_path attribute" do
    it "has a package_path attribute" do
      assoc = described_class.new
      expect(assoc).to respond_to(:package_path)
      expect(assoc).to respond_to(:package_path=)
    end

    it "can be set and retrieved" do
      assoc = described_class.new
      assoc.package_path = "ModelRoot::TestPackage::SubPackage"
      expect(assoc.package_path).to eq("ModelRoot::TestPackage::SubPackage")
    end

    it "defaults to nil when not set" do
      assoc = described_class.new
      expect(assoc.package_path).to be_nil
    end

    it "can be set during initialization" do
      assoc = described_class.new(
        owner_end: "ClassA",
        member_end: "ClassB",
        package_path: "ModelRoot::Package1"
      )
      expect(assoc.package_path).to eq("ModelRoot::Package1")
    end
  end

  describe "serialization" do
    it "includes package_path in YAML serialization" do
      assoc = described_class.new(
        owner_end: "ClassA",
        member_end: "ClassB",
        package_path: "ModelRoot::TestPackage"
      )

      yaml_output = assoc.to_yaml
      expect(yaml_output).to include("package_path")
      expect(yaml_output).to include("ModelRoot::TestPackage")
    end

    it "deserializes package_path from YAML" do
      yaml_str = <<~YAML
        owner_end: ClassA
        member_end: ClassB
        package_path: ModelRoot::TestPackage::SubPackage
      YAML

      assoc = described_class.from_yaml(yaml_str)
      expect(assoc.package_path).to eq("ModelRoot::TestPackage::SubPackage")
    end
  end

  context "with QEA parsing" do
    let(:qea_path) { fixtures_path("plateau_all_packages.qea") }

    before do
      skip "QEA fixture not available" unless File.exist?(qea_path)
    end

    it "sets package_path when parsing QEA files" do
      documents = Lutaml::Parser.parse([File.new(qea_path)])
      document = documents.first

      # Find a class with associations
      assoc = nil
      document.packages.each do |pkg|
        pkg.classes.each do |klass|
          assoc = klass.associations&.first
          break if assoc
        end
        break if assoc
      end

      if assoc
        expect(assoc.package_path).not_to be_nil
        expect(assoc.package_path).to be_a(String)
        expect(assoc.package_path).to include("::")
      end
    end

    it "calculates nested package paths correctly for associations" do
      documents = Lutaml::Parser.parse([File.new(qea_path)])
      document = documents.first

      # Find an association in a deeply nested package
      nested_assoc = nil
      document.packages.each do |pkg|
        pkg.packages.each do |sub_pkg|
          sub_pkg.classes.each do |klass|
            nested_assoc = klass.associations&.first
            break if nested_assoc
          end
          break if nested_assoc
        end
        break if nested_assoc
      end

      if nested_assoc
        expect(nested_assoc.package_path).not_to be_nil
        # Should have at least 2 levels
        expect(nested_assoc.package_path.count("::")).to be >= 1
      end
    end
  end

  context "with XMI parsing" do
    let(:xmi_path) { fixtures_path("ea-xmi-2.5.1.xmi") }

    before do
      skip "XMI fixture not available" unless File.exist?(xmi_path)
    end

    it "sets package_path when parsing XMI files" do
      documents = Lutaml::Parser.parse([File.new(xmi_path)])
      document = documents.first

      # Find a class with associations
      assoc = nil
      document.packages.each do |pkg|
        pkg.classes.each do |klass|
          assoc = klass.associations&.first
          break if assoc
        end
        break if assoc
      end

      if assoc
        expect(assoc.package_path).not_to be_nil
        expect(assoc.package_path).to be_a(String)
      end
    end

    it "uses the correct package hierarchy in XMI" do
      documents = Lutaml::Parser.parse([File.new(xmi_path)])
      document = documents.first

      # Verify that association package_path matches the class package
      document.packages.each do |pkg|
        pkg.classes.each do |klass|
          klass.associations&.each do |assoc|
            if assoc.package_path && klass.package_path
              # Association should be in same package as its owner class
              expect(assoc.package_path).to eq(klass.package_path)
            end
          end
        end
      end
    end
  end

  context "with Repository queries" do
    let(:qea_path) { fixtures_path("plateau_all_packages.qea") }

    before do
      skip "QEA fixture not available" unless File.exist?(qea_path)
    end

    it "can query associations by package_path" do
      repo = Lutaml::UmlRepository::Repository.from_file(qea_path)

      # Get a package path from an existing association
      sample_assoc = repo.associations_index.find { |a| a.package_path }

      if sample_assoc
        results = repo.find_associations_by_package(sample_assoc.package_path)

        expect(results).to be_an(Array)
        expect(results).to include(sample_assoc)

        # All results should have matching package_path
        results.each do |assoc|
          expect(assoc.package_path).to eq(sample_assoc.package_path)
        end
      end
    end

    it "returns empty array for non-existent package path" do
      repo = Lutaml::UmlRepository::Repository.from_file(qea_path)
      results = repo.find_associations_by_package("NonExistent::Package::Path")

      expect(results).to eq([])
    end

    it "supports recursive package queries" do
      repo = Lutaml::UmlRepository::Repository.from_file(qea_path)

      # Find a parent package path
      sample_assoc = repo.associations_index.find { |a| a.package_path }

      if sample_assoc&.package_path
        parent_path = sample_assoc.package_path.split("::")[0..-2].join("::")

        if !parent_path.empty?
          results = repo.find_associations_by_package(parent_path, recursive: true)

          expect(results).to be_an(Array)
          expect(results.size).to be > 0

          # Should include associations from nested packages
          results.each do |assoc|
            path = assoc.package_path || ""
            expect(path).to start_with(parent_path) if !path.empty?
          end
        end
      end
    end

    it "supports non-recursive package queries" do
      repo = Lutaml::UmlRepository::Repository.from_file(qea_path)

      # Find a parent package path with nested packages
      sample_assoc = repo.associations_index.find { |a| a.package_path }

      if sample_assoc&.package_path
        parent_path = sample_assoc.package_path.split("::")[0..-2].join("::")

        if !parent_path.empty?
          recursive_results = repo.find_associations_by_package(parent_path, recursive: true)
          non_recursive_results = repo.find_associations_by_package(parent_path, recursive: false)

          # Non-recursive should be a subset of recursive
          expect(non_recursive_results.size).to be <= recursive_results.size

          # Non-recursive results should have exact match
          non_recursive_results.each do |assoc|
            expect(assoc.package_path).to eq(parent_path)
          end
        end
      end
    end
  end

  describe "edge cases" do
    it "handles nil package_path gracefully" do
      assoc = described_class.new(owner_end: "ClassA", member_end: "ClassB")
      expect(assoc.package_path).to be_nil
      expect { assoc.to_yaml }.not_to raise_error
    end

    it "handles empty package_path" do
      assoc = described_class.new(
        owner_end: "ClassA",
        member_end: "ClassB",
        package_path: ""
      )
      expect(assoc.package_path).to eq("")
    end

    it "handles single-level package path" do
      assoc = described_class.new(
        owner_end: "ClassA",
        member_end: "ClassB",
        package_path: "Root"
      )
      expect(assoc.package_path).to eq("Root")
    end

    it "handles deeply nested package paths" do
      path = "Level1::Level2::Level3::Level4::Level5"
      assoc = described_class.new(
        owner_end: "ClassA",
        member_end: "ClassB",
        package_path: path
      )
      expect(assoc.package_path).to eq(path)
    end
  end
end