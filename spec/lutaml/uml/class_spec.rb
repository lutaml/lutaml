# frozen_string_literal: true

require "spec_helper"

RSpec.describe Lutaml::Uml::Class do
  describe "package_path attribute" do
    it "has a package_path attribute" do
      klass = described_class.new
      expect(klass).to respond_to(:package_path)
      expect(klass).to respond_to(:package_path=)
    end

    it "can be set and retrieved" do
      klass = described_class.new
      klass.package_path = "ModelRoot::TestPackage::SubPackage"
      expect(klass.package_path).to eq("ModelRoot::TestPackage::SubPackage")
    end

    it "defaults to nil when not set" do
      klass = described_class.new
      expect(klass.package_path).to be_nil
    end

    it "can be set during initialization" do
      klass = described_class.new(
        name: "TestClass",
        package_path: "ModelRoot::Package1"
      )
      expect(klass.package_path).to eq("ModelRoot::Package1")
    end
  end

  describe "serialization" do
    it "includes package_path in YAML serialization" do
      klass = described_class.new(
        name: "TestClass",
        package_path: "ModelRoot::TestPackage"
      )

      yaml_output = klass.to_yaml
      expect(yaml_output).to include("package_path")
      expect(yaml_output).to include("ModelRoot::TestPackage")
    end

    it "deserializes package_path from YAML" do
      yaml_str = <<~YAML
        name: TestClass
        package_path: ModelRoot::TestPackage::SubPackage
      YAML

      klass = described_class.from_yaml(yaml_str)
      expect(klass.package_path).to eq("ModelRoot::TestPackage::SubPackage")
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

      # Find a class with a package
      klass = document.packages.first&.classes&.first

      if klass
        expect(klass.package_path).not_to be_nil
        expect(klass.package_path).to be_a(String)
        expect(klass.package_path).to include("::")
      end
    end

    it "calculates nested package paths correctly" do
      documents = Lutaml::Parser.parse([File.new(qea_path)])
      document = documents.first

      # Find a deeply nested class
      nested_class = nil
      document.packages.each do |pkg|
        pkg.packages.each do |sub_pkg|
          nested_class = sub_pkg.classes.first
          break if nested_class
        end
        break if nested_class
      end

      if nested_class
        expect(nested_class.package_path).not_to be_nil
        # Should have at least 2 levels
        expect(nested_class.package_path.count("::")).to be >= 1
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

      # Find a class with a package
      klass = document.packages.first&.classes&.first

      if klass
        expect(klass.package_path).not_to be_nil
        expect(klass.package_path).to be_a(String)
      end
    end

    it "uses the correct package hierarchy in XMI" do
      documents = Lutaml::Parser.parse([File.new(xmi_path)])
      document = documents.first

      # Verify that package_path matches the actual package structure
      document.packages.each do |pkg|
        pkg.classes.each do |klass|
          if klass.package_path
            # Package path should end with the immediate parent package name
            expect(klass.package_path).to end_with(pkg.name)
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

    it "can query classes by package_path" do
      repo = Lutaml::UmlRepository::Repository.from_file(qea_path)

      # Get a package path from an existing class
      sample_class = repo.classes_index.first

      if sample_class&.package_path
        results = repo.find_classes_by_package(sample_class.package_path)

        expect(results).to be_an(Array)
        expect(results).to include(sample_class)

        # All results should have matching package_path
        results.each do |klass|
          expect(klass.package_path).to eq(sample_class.package_path)
        end
      end
    end

    it "returns empty array for non-existent package path" do
      repo = Lutaml::UmlRepository::Repository.from_file(qea_path)
      results = repo.find_classes_by_package("NonExistent::Package::Path")

      expect(results).to eq([])
    end

    it "supports recursive package queries" do
      repo = Lutaml::UmlRepository::Repository.from_file(qea_path)

      # Find a parent package path
      sample_class = repo.classes_index.first

      if sample_class&.package_path
        parent_path = sample_class.package_path.split("::")[0..-2].join("::")

        if !parent_path.empty?
          results = repo.find_classes_by_package(parent_path, recursive: true)

          expect(results).to be_an(Array)
          expect(results.size).to be > 0

          # Should include classes from nested packages
          results.each do |klass|
            path = klass.package_path || ""
            expect(path).to start_with(parent_path) if !path.empty?
          end
        end
      end
    end

    it "supports non-recursive package queries" do
      repo = Lutaml::UmlRepository::Repository.from_file(qea_path)

      # Find a parent package path with nested packages
      sample_class = repo.classes_index.first

      if sample_class&.package_path
        parent_path = sample_class.package_path.split("::")[0..-2].join("::")

        if !parent_path.empty?
          recursive_results = repo.find_classes_by_package(parent_path, recursive: true)
          non_recursive_results = repo.find_classes_by_package(parent_path, recursive: false)

          # Non-recursive should be a subset of recursive
          expect(non_recursive_results.size).to be <= recursive_results.size

          # Non-recursive results should have exact match
          non_recursive_results.each do |klass|
            expect(klass.package_path).to eq(parent_path)
          end
        end
      end
    end
  end

  describe "edge cases" do
    it "handles nil package_path gracefully" do
      klass = described_class.new(name: "TestClass")
      expect(klass.package_path).to be_nil
      expect { klass.to_yaml }.not_to raise_error
    end

    it "handles empty package_path" do
      klass = described_class.new(name: "TestClass", package_path: "")
      expect(klass.package_path).to eq("")
    end

    it "handles single-level package path" do
      klass = described_class.new(name: "TestClass", package_path: "Root")
      expect(klass.package_path).to eq("Root")
    end

    it "handles deeply nested package paths" do
      path = "Level1::Level2::Level3::Level4::Level5"
      klass = described_class.new(name: "TestClass", package_path: path)
      expect(klass.package_path).to eq(path)
    end
  end
end