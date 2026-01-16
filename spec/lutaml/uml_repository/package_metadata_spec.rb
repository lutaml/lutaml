# frozen_string_literal: true

require "spec_helper"
require "lutaml/uml_repository/package_metadata"

RSpec.describe Lutaml::UmlRepository::PackageMetadata do
  describe "#initialize" do
    it "creates metadata with required fields" do
      metadata = described_class.new(
        name: "Test Model",
        version: "1.0.0",
      )

      expect(metadata.name).to eq("Test Model")
      expect(metadata.version).to eq("1.0.0")
    end

    it "creates metadata with all fields" do
      metadata = described_class.new(
        name: "Urban Planning",
        version: "2.3.0",
        publisher: "City Planning",
        license: "CC-BY-4.0",
        description: "Urban planning model",
        keywords: "urban, planning, infrastructure",
        homepage: "https://example.com",
        authors: ["Jane Doe", "John Smith"],
        maintainers: "team@example.com",
        serialization_format: "marshal",
      )

      expect(metadata.name).to eq("Urban Planning")
      expect(metadata.version).to eq("2.3.0")
      expect(metadata.publisher).to eq("City Planning")
      expect(metadata.license).to eq("CC-BY-4.0")
      expect(metadata.description).to eq("Urban planning model")
      expect(metadata.keywords).to eq("urban, planning, infrastructure")
      expect(metadata.homepage).to eq("https://example.com")
      expect(metadata.authors).to eq(["Jane Doe", "John Smith"])
      expect(metadata.maintainers).to eq("team@example.com")
      expect(metadata.serialization_format).to eq("marshal")
    end

    it "initializes authors as empty array by default" do
      metadata = described_class.new(
        name: "Test",
        version: "1.0",
      )

      expect(metadata.authors).to eq([])
    end

    it "allows creation with missing name (validation happens later)" do
      metadata = described_class.new(version: "1.0")
      expect(metadata.name).to be_nil
      expect(metadata.version).to eq("1.0")
    end

    it "allows creation with missing version (validation happens later)" do
      metadata = described_class.new(name: "Test")
      expect(metadata.name).to eq("Test")
      expect(metadata.version).to be_nil
    end

    it "allows creation with empty strings (validation happens later)" do
      metadata = described_class.new(name: "", version: "")
      expect(metadata.name).to eq("")
      expect(metadata.version).to eq("")
    end
  end

  describe "#validate" do
    it "returns empty errors array when required fields are present" do
      metadata = described_class.new(name: "Test", version: "1.0")
      errors = metadata.validate
      expect(errors).to be_empty
    end

    it "returns error when name is nil" do
      metadata = described_class.new(name: nil, version: "1.0")
      errors = metadata.validate
      expect(errors.size).to eq(1)
      expect(errors.first.message).to match(/name is required/)
    end

    it "returns error when name is empty string" do
      metadata = described_class.new(name: "", version: "1.0")
      errors = metadata.validate
      expect(errors.size).to eq(1)
      expect(errors.first.message).to match(/name is required/)
    end

    it "returns error when version is nil" do
      metadata = described_class.new(name: "Test", version: nil)
      errors = metadata.validate
      expect(errors.size).to eq(1)
      expect(errors.first.message).to match(/version is required/)
    end

    it "returns error when version is empty string" do
      metadata = described_class.new(name: "Test", version: "")
      errors = metadata.validate
      expect(errors.size).to eq(1)
      expect(errors.first.message).to match(/version is required/)
    end

    it "returns multiple errors when both required fields missing" do
      metadata = described_class.new(publisher: "ACME")
      errors = metadata.validate
      expect(errors.size).to eq(2)
      expect(errors.map(&:message)).to include(
        match(/name is required/),
        match(/version is required/),
      )
    end
  end

  describe "#validate!" do
    it "does not raise when required fields are present" do
      expect do
        described_class.new(name: "Test", version: "1.0").validate!
      end.not_to raise_error
    end

    it "raises when name is nil" do
      expect do
        described_class.new(name: nil, version: "1.0").validate!
      end.to raise_error(Lutaml::Model::ValidationError, /name is required/)
    end

    it "raises when version is nil" do
      expect do
        described_class.new(name: "Test", version: nil).validate!
      end.to raise_error(Lutaml::Model::ValidationError, /version is required/)
    end

    it "raises with multiple errors when both fields missing" do
      expect do
        described_class.new(publisher: "ACME").validate!
      end.to raise_error(Lutaml::Model::ValidationError,
                         /name is required.*version is required/)
    end
  end

  describe "YAML serialization" do
    it "round-trips through YAML with all fields" do
      original = described_class.new(
        name: "Urban Planning",
        version: "2.3.0",
        publisher: "City Planning",
        license: "CC-BY-4.0",
        description: "Urban planning model",
        keywords: "urban, planning",
        homepage: "https://example.com",
        authors: ["Jane Doe", "John Smith"],
        maintainers: "team@example.com",
        serialization_format: "marshal",
      )

      yaml = original.to_yaml
      restored = described_class.from_yaml(yaml)

      expect(restored.name).to eq(original.name)
      expect(restored.version).to eq(original.version)
      expect(restored.publisher).to eq(original.publisher)
      expect(restored.license).to eq(original.license)
      expect(restored.description).to eq(original.description)
      expect(restored.keywords).to eq(original.keywords)
      expect(restored.homepage).to eq(original.homepage)
      expect(restored.authors).to eq(original.authors)
      expect(restored.maintainers).to eq(original.maintainers)
      expect(restored.serialization_format).to eq(original.serialization_format)
    end

    it "round-trips through YAML with minimal metadata" do
      original = described_class.new(
        name: "Simple",
        version: "1.0",
      )

      yaml = original.to_yaml
      restored = described_class.from_yaml(yaml)

      expect(restored.name).to eq(original.name)
      expect(restored.version).to eq(original.version)
      expect(restored.authors).to eq([])
    end
  end
end