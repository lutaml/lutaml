# frozen_string_literal: true

require "spec_helper"

RSpec.describe Expressir::SchemaManifestEntry do
  describe "#initialize" do
    it "creates an entry with path" do
      entry = described_class.new(path: "test.exp")

      expect(entry.path).to eq("test.exp")
      expect(entry.id).to be_nil
    end

    it "creates an entry with all attributes" do
      entry = described_class.new(
        path: "test.exp",
        id: "test_schema",
      )

      expect(entry.path).to eq("test.exp")
      expect(entry.id).to eq("test_schema")
    end

    it "can be created without parameters" do
      entry = described_class.new

      expect(entry.path).to be_nil
      expect(entry.id).to be_nil
    end
  end

  describe "#container_path" do
    it "can set and get container_path" do
      entry = described_class.new(path: "test.exp")
      entry.container_path = "/path/to/container"

      expect(entry.container_path).to eq("/path/to/container")
    end
  end

  describe "attribute access" do
    it "allows reading and writing id" do
      entry = described_class.new
      entry.id = "new_id"

      expect(entry.id).to eq("new_id")
    end

    it "allows reading and writing path" do
      entry = described_class.new
      entry.path = "new_path.exp"

      expect(entry.path).to eq("new_path.exp")
    end
  end

  describe "serialization" do
    it "can be serialized to YAML and back" do
      entry = described_class.new(id: "test_schema", path: "test.exp")

      yaml_string = entry.to_yaml
      expect(yaml_string).to include("id: test_schema")
      expect(yaml_string).to include("path: test.exp")

      # Test round-trip
      reloaded = described_class.from_yaml(yaml_string)
      expect(reloaded.id).to eq("test_schema")
      expect(reloaded.path).to eq("test.exp")
    end
  end

  describe "equality" do
    it "considers entries with same attributes equal" do
      entry1 = described_class.new(path: "test.exp", id: "test")
      entry2 = described_class.new(path: "test.exp", id: "test")

      expect(entry1.id).to eq(entry2.id)
      expect(entry1.path).to eq(entry2.path)
    end

    it "considers entries with different attributes different" do
      entry1 = described_class.new(path: "test.exp", id: "test1")
      entry2 = described_class.new(path: "test.exp", id: "test2")

      expect(entry1.id).not_to eq(entry2.id)
    end
  end
end
