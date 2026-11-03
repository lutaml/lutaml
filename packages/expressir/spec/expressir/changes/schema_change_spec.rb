# frozen_string_literal: true

require "spec_helper"
require "expressir/changes"

RSpec.describe Expressir::Changes::SchemaChange do
  let(:simple_fixture) do
    File.join(__dir__, "../../fixtures/changes/simple_change.yaml")
  end

  let(:complete_fixture) do
    File.join(__dir__, "../../fixtures/changes/complete_change.yaml")
  end

  let(:mapping_fixture) do
    File.join(__dir__, "../../fixtures/changes/mapping_change.yaml")
  end

  describe ".from_file" do
    it "loads a simple change file" do
      schema = described_class.from_file(simple_fixture)

      expect(schema.schema).to eq("test_schema")
      expect(schema.versions.size).to eq(1)
      expect(schema.versions[0].version).to eq(2)
      expect(schema.versions[0].modifications.size).to eq(1)
      expect(schema.versions[0].modifications[0].type).to eq("TYPE")
      expect(schema.versions[0].modifications[0].name).to eq("text")
    end

    it "loads a complete change file with multiple versions" do
      schema = described_class.from_file(complete_fixture)

      expect(schema.schema).to eq("topology_schema")
      expect(schema.versions.size).to eq(2)

      # Check first version
      ed1 = schema.versions[0]
      expect(ed1.version).to eq(2)
      expect(ed1.additions.size).to eq(2)
      expect(ed1.modifications.size).to eq(2)

      # Check second version with deletions
      ed2 = schema.versions[1]
      expect(ed2.version).to eq(7)
      expect(ed2.deletions.size).to eq(2)
      expect(ed2.deletions[0].interfaced_items).to eq("length_measure")
    end

    it "loads a mapping change file" do
      schema = described_class.from_file(mapping_fixture)

      expect(schema.schema).to eq("advanced_boundary_representation")
      expect(schema.versions.size).to eq(1)
      expect(schema.versions[0].mappings.size).to eq(2)
      expect(schema.versions[0].mappings[0].description).to include("mapping")
    end

    it "handles empty files" do
      require "tempfile"
      Tempfile.create(["empty", ".yaml"]) do |f|
        f.write("---\n")
        f.rewind

        schema = described_class.from_file(f.path)
        expect(schema.schema).to be_nil
        expect(schema.versions).to be_nil
      end
    end
  end

  describe "#add_or_update_version" do
    let(:schema) { described_class.new(schema: "test_schema") }

    it "adds a new version" do
      changes = {
        additions: [
          Expressir::Changes::ItemChange.new(type: "ENTITY",
                                             name: "new_entity"),
        ],
        modifications: [],
        deletions: [],
      }

      schema.add_or_update_version(2, "Added new entity", changes)

      expect(schema.versions.size).to eq(1)
      expect(schema.versions[0].version).to eq(2)
      expect(schema.versions[0].additions.size).to eq(1)
    end

    it "replaces an existing version with same version" do
      changes1 = {
        additions: [
          Expressir::Changes::ItemChange.new(type: "ENTITY", name: "entity1"),
        ],
        modifications: [],
        deletions: [],
      }
      schema.add_or_update_version(2, "First description", changes1)

      changes2 = {
        additions: [
          Expressir::Changes::ItemChange.new(type: "ENTITY", name: "entity2"),
        ],
        modifications: [],
        deletions: [],
      }
      schema.add_or_update_version(2, "Second description", changes2)

      expect(schema.versions.size).to eq(1)
      expect(schema.versions[0].description).to eq("Second description")
      expect(schema.versions[0].additions[0].name).to eq("entity2")
    end

    it "adds new version when version is different" do
      changes1 = {
        additions: [
          Expressir::Changes::ItemChange.new(type: "ENTITY", name: "entity1"),
        ],
        modifications: [],
        deletions: [],
      }
      schema.add_or_update_version(2, "Version 2", changes1)

      changes2 = {
        additions: [
          Expressir::Changes::ItemChange.new(type: "ENTITY", name: "entity2"),
        ],
        modifications: [],
        deletions: [],
      }
      schema.add_or_update_version(3, "Version 3", changes2)

      expect(schema.versions.size).to eq(2)
      expect(schema.versions[0].version).to eq(2)
      expect(schema.versions[1].version).to eq(3)
    end
  end

  describe "#to_file" do
    it "saves the change schema to a file" do
      require "tempfile"
      schema = described_class.from_file(simple_fixture)

      Tempfile.create(["output", ".yaml"]) do |f|
        schema.to_file(f.path)

        # Verify file was written
        content = File.read(f.path)
        expect(content).to include("schema: test_schema")
        expect(content).to include("version: 2")

        # Verify it can be read back
        reloaded = described_class.from_file(f.path)
        expect(reloaded.schema).to eq(schema.schema)
        expect(reloaded.versions.size).to eq(schema.versions.size)
      end
    end
  end

  describe "round-trip" do
    it "maintains data integrity for simple change" do
      schema = described_class.from_file(simple_fixture)
      yaml_output = schema.to_yaml
      reloaded = described_class.from_yaml(yaml_output)

      expect(reloaded.schema).to eq(schema.schema)
      expect(reloaded.versions.size).to eq(schema.versions.size)
      expect(reloaded.versions[0].version).to eq(schema.versions[0].version)
    end

    it "maintains data integrity for complete change" do
      schema = described_class.from_file(complete_fixture)
      yaml_output = schema.to_yaml
      reloaded = described_class.from_yaml(yaml_output)

      expect(reloaded.schema).to eq(schema.schema)
      expect(reloaded.versions.size).to eq(schema.versions.size)

      # Verify deletions field
      ed2 = reloaded.versions[1]
      expect(ed2.deletions.size).to eq(schema.versions[1].deletions.size)
    end
  end
end
