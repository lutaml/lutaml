# frozen_string_literal: true

require "spec_helper"
require "expressir/package/metadata"

RSpec.describe Expressir::Package::Metadata do
  describe "#initialize" do
    it "creates metadata with defaults" do
      metadata = described_class.new(
        name: "Test Package",
        version: "1.0.0",
      )

      expect(metadata.name).to eq("Test Package")
      expect(metadata.version).to eq("1.0.0")
      expect(metadata.created_by).to eq("expressir")
      expect(metadata.express_mode).to eq("include_all")
      expect(metadata.resolution_mode).to eq("resolved")
      expect(metadata.serialization_format).to eq("marshal")
    end

    it "creates metadata with custom values" do
      metadata = described_class.new(
        name: "Custom Package",
        version: "2.0.0",
        description: "A test package",
        created_by: "test_user",
        express_mode: "allow_external",
        resolution_mode: "bare",
        serialization_format: "json",
      )

      expect(metadata.name).to eq("Custom Package")
      expect(metadata.version).to eq("2.0.0")
      expect(metadata.description).to eq("A test package")
      expect(metadata.created_by).to eq("test_user")
      expect(metadata.express_mode).to eq("allow_external")
      expect(metadata.resolution_mode).to eq("bare")
      expect(metadata.serialization_format).to eq("json")
    end
  end

  describe "#validate" do
    it "validates valid metadata" do
      metadata = described_class.new(
        name: "Valid Package",
        version: "1.0.0",
      )

      result = metadata.validate
      expect(result[:valid?]).to be true
      expect(result[:errors]).to be_empty
    end

    it "rejects metadata without name" do
      metadata = described_class.new(
        version: "1.0.0",
      )

      result = metadata.validate
      expect(result[:valid?]).to be false
      expect(result[:errors]).to include("name is required")
    end

    it "rejects metadata without version" do
      metadata = described_class.new(
        name: "Test Package",
      )

      result = metadata.validate
      expect(result[:valid?]).to be false
      expect(result[:errors]).to include("version is required")
    end

    it "rejects invalid express_mode" do
      metadata = described_class.new(
        name: "Test Package",
        version: "1.0.0",
        express_mode: "invalid_mode",
      )

      result = metadata.validate
      expect(result[:valid?]).to be false
      expect(result[:errors]).to include(
        "express_mode must be 'include_all' or 'allow_external'",
      )
    end

    it "rejects invalid resolution_mode" do
      metadata = described_class.new(
        name: "Test Package",
        version: "1.0.0",
        resolution_mode: "invalid_mode",
      )

      result = metadata.validate
      expect(result[:valid?]).to be false
      expect(result[:errors]).to include(
        "resolution_mode must be 'resolved' or 'bare'",
      )
    end

    it "rejects invalid serialization_format" do
      metadata = described_class.new(
        name: "Test Package",
        version: "1.0.0",
        serialization_format: "invalid_format",
      )

      result = metadata.validate
      expect(result[:valid?]).to be false
      expect(result[:errors]).to include(
        "serialization_format must be 'marshal', 'json', or 'yaml'",
      )
    end

    it "collects multiple validation errors" do
      metadata = described_class.new(
        express_mode: "invalid",
        resolution_mode: "invalid",
        serialization_format: "invalid",
      )

      result = metadata.validate
      expect(result[:valid?]).to be false
      expect(result[:errors].size).to eq(5) # name, version, + 3 mode errors
    end
  end

  describe "YAML serialization" do
    it "serializes to YAML" do
      metadata = described_class.new(
        name: "YAML Package",
        version: "1.0.0",
        description: "Test description",
        files: 5,
        schemas: 3,
      )

      yaml = metadata.to_yaml
      expect(yaml).to include("name: YAML Package")
      expect(yaml).to match(/version: ['"]?1\.0\.0['"]?/)
      expect(yaml).to include("description: Test description")
      expect(yaml).to include("files: 5")
      expect(yaml).to include("schemas: 3")
    end

    it "deserializes from YAML" do
      yaml = <<~YAML
        name: Test Package
        version: 1.0.0
        description: A test package
        created_by: expressir
        express_mode: include_all
        resolution_mode: resolved
        serialization_format: marshal
        files: 10
        schemas: 5
      YAML

      metadata = described_class.from_yaml(yaml)
      expect(metadata.name).to eq("Test Package")
      expect(metadata.version).to eq("1.0.0")
      expect(metadata.description).to eq("A test package")
      expect(metadata.files).to eq(10)
      expect(metadata.schemas).to eq(5)
    end

    it "round-trips through YAML" do
      original = described_class.new(
        name: "Round Trip Package",
        version: "2.0.0",
        description: "Test round trip",
        express_mode: "allow_external",
        resolution_mode: "bare",
        serialization_format: "yaml",
        files: 15,
        schemas: 8,
      )

      yaml = original.to_yaml
      restored = described_class.from_yaml(yaml)

      expect(restored.name).to eq(original.name)
      expect(restored.version).to eq(original.version)
      expect(restored.description).to eq(original.description)
      expect(restored.express_mode).to eq(original.express_mode)
      expect(restored.resolution_mode).to eq(original.resolution_mode)
      expect(restored.serialization_format).to eq(original.serialization_format)
      expect(restored.files).to eq(original.files)
      expect(restored.schemas).to eq(original.schemas)
    end
  end

  describe "configuration modes" do
    it "supports include_all express mode" do
      metadata = described_class.new(
        name: "Test",
        version: "1.0",
        express_mode: "include_all",
      )

      expect(metadata.validate[:valid?]).to be true
    end

    it "supports allow_external express mode" do
      metadata = described_class.new(
        name: "Test",
        version: "1.0",
        express_mode: "allow_external",
      )

      expect(metadata.validate[:valid?]).to be true
    end

    it "supports resolved resolution mode" do
      metadata = described_class.new(
        name: "Test",
        version: "1.0",
        resolution_mode: "resolved",
      )

      expect(metadata.validate[:valid?]).to be true
    end

    it "supports bare resolution mode" do
      metadata = described_class.new(
        name: "Test",
        version: "1.0",
        resolution_mode: "bare",
      )

      expect(metadata.validate[:valid?]).to be true
    end

    it "supports marshal serialization format" do
      metadata = described_class.new(
        name: "Test",
        version: "1.0",
        serialization_format: "marshal",
      )

      expect(metadata.validate[:valid?]).to be true
    end

    it "supports json serialization format" do
      metadata = described_class.new(
        name: "Test",
        version: "1.0",
        serialization_format: "json",
      )

      expect(metadata.validate[:valid?]).to be true
    end

    it "supports yaml serialization format" do
      metadata = described_class.new(
        name: "Test",
        version: "1.0",
        serialization_format: "yaml",
      )

      expect(metadata.validate[:valid?]).to be true
    end
  end
end
