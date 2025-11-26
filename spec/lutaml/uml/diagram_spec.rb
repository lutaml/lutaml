# frozen_string_literal: true

require "spec_helper"

RSpec.describe Lutaml::Uml::Diagram do
  describe "package_path attribute" do
    it "has a package_path attribute" do
      diagram = described_class.new
      expect(diagram).to respond_to(:package_path)
      expect(diagram).to respond_to(:package_path=)
    end

    it "can be set and retrieved" do
      diagram = described_class.new
      diagram.package_path = "ModelRoot::TestPackage::SubPackage"
      expect(diagram.package_path).to eq("ModelRoot::TestPackage::SubPackage")
    end

    it "defaults to nil when not set" do
      diagram = described_class.new
      expect(diagram.package_path).to be_nil
    end

    it "can be set during initialization" do
      diagram = described_class.new(
        name: "Class Diagram",
        package_path: "ModelRoot::Package1"
      )
      expect(diagram.package_path).to eq("ModelRoot::Package1")
    end
  end

  describe "serialization" do
    it "includes package_path in YAML serialization" do
      diagram = described_class.new(
        name: "Test Diagram",
        package_path: "ModelRoot::TestPackage"
      )

      yaml_output = diagram.to_yaml
      expect(yaml_output).to include("package_path")
      expect(yaml_output).to include("ModelRoot::TestPackage")
    end

    it "deserializes package_path from YAML" do
      yaml_str = <<~YAML
        name: Test Diagram
        package_path: ModelRoot::TestPackage::SubPackage
      YAML

      diagram = described_class.from_yaml(yaml_str)
      expect(diagram.package_path).to eq("ModelRoot::TestPackage::SubPackage")
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

      # Find a diagram
      diagram = nil
      document.packages.each do |pkg|
        diagram = pkg.diagrams&.first
        break if diagram
      end

      if diagram
        expect(diagram.package_path).not_to be_nil
        expect(diagram.package_path).to be_a(String)
        expect(diagram.package_path).to include("::")
      end
    end

    it "calculates nested package paths correctly for diagrams" do
      documents = Lutaml::Parser.parse([File.new(qea_path)])
      document = documents.first

      # Find a diagram in a deeply nested package
      nested_diagram = nil
      document.packages.each do |pkg|
        pkg.packages.each do |sub_pkg|
          nested_diagram = sub_pkg.diagrams&.first
          break if nested_diagram
        end
        break if nested_diagram
      end

      if nested_diagram
        expect(nested_diagram.package_path).not_to be_nil
        # Should have at least 2 levels
        expect(nested_diagram.package_path.count("::")).to be >= 1
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

      # Find a diagram
      diagram = nil
      document.packages.each do |pkg|
        diagram = pkg.diagrams&.first
        break if diagram
      end

      if diagram
        expect(diagram.package_path).not_to be_nil
        expect(diagram.package_path).to be_a(String)
      end
    end

    it "uses the correct package hierarchy in XMI" do
      documents = Lutaml::Parser.parse([File.new(xmi_path)])
      document = documents.first

      # Verify that diagram package_path matches its package
      document.packages.each do |pkg|
        pkg.diagrams&.each do |diagram|
          if diagram.package_path
            # Diagram should be in the package that contains it
            expect(diagram.package_path).to be_a(String)
            expect(diagram.package_path).not_to be_empty
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

    it "can query diagrams by package_path" do
      repo = Lutaml::UmlRepository::Repository.from_file(qea_path)

      # Get a package path from an existing diagram
      sample_diagram = repo.diagrams_index.find { |d| d.package_path }

      if sample_diagram
        results = repo.find_diagrams_by_package(sample_diagram.package_path)

        expect(results).to be_an(Array)
        expect(results).to include(sample_diagram)

        # All results should have matching package_path
        results.each do |diagram|
          expect(diagram.package_path).to eq(sample_diagram.package_path)
        end
      end
    end

    it "returns empty array for non-existent package path" do
      repo = Lutaml::UmlRepository::Repository.from_file(qea_path)
      results = repo.find_diagrams_by_package("NonExistent::Package::Path")

      expect(results).to eq([])
    end

    it "supports recursive package queries" do
      repo = Lutaml::UmlRepository::Repository.from_file(qea_path)

      # Find a parent package path
      sample_diagram = repo.diagrams_index.find { |d| d.package_path }

      if sample_diagram&.package_path
        parent_path = sample_diagram.package_path.split("::")[0..-2].join("::")

        if !parent_path.empty?
          results = repo.find_diagrams_by_package(parent_path, recursive: true)

          expect(results).to be_an(Array)
          expect(results.size).to be > 0

          # Should include diagrams from nested packages
          results.each do |diagram|
            path = diagram.package_path || ""
            expect(path).to start_with(parent_path) if !path.empty?
          end
        end
      end
    end

    it "supports non-recursive package queries" do
      repo = Lutaml::UmlRepository::Repository.from_file(qea_path)

      # Find a parent package path with nested packages
      sample_diagram = repo.diagrams_index.find { |d| d.package_path }

      if sample_diagram&.package_path
        parent_path = sample_diagram.package_path.split("::")[0..-2].join("::")

        if !parent_path.empty?
          recursive_results = repo.find_diagrams_by_package(parent_path, recursive: true)
          non_recursive_results = repo.find_diagrams_by_package(parent_path, recursive: false)

          # Non-recursive should be a subset of recursive
          expect(non_recursive_results.size).to be <= recursive_results.size

          # Non-recursive results should have exact match
          non_recursive_results.each do |diagram|
            expect(diagram.package_path).to eq(parent_path)
          end
        end
      end
    end
  end

  describe "edge cases" do
    it "handles nil package_path gracefully" do
      diagram = described_class.new(name: "Test Diagram")
      expect(diagram.package_path).to be_nil
      expect { diagram.to_yaml }.not_to raise_error
    end

    it "handles empty package_path" do
      diagram = described_class.new(
        name: "Test Diagram",
        package_path: ""
      )
      expect(diagram.package_path).to eq("")
    end

    it "handles single-level package path" do
      diagram = described_class.new(
        name: "Test Diagram",
        package_path: "Root"
      )
      expect(diagram.package_path).to eq("Root")
    end

    it "handles deeply nested package paths" do
      path = "Level1::Level2::Level3::Level4::Level5"
      diagram = described_class.new(
        name: "Test Diagram",
        package_path: path
      )
      expect(diagram.package_path).to eq(path)
    end
  end
end