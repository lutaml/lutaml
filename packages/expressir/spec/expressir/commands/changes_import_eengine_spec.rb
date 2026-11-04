# frozen_string_literal: true

require "spec_helper"
require "expressir/commands/changes_import_eengine"

RSpec.describe Expressir::Commands::ChangesImportEengine do
  let(:xml_fixture) do
    File.join(__dir__, "../../fixtures/changes/sample_eengine.xml")
  end

  let(:schema_name) { "support_resource_schema" }
  let(:version) { 2 }

  describe ".call" do
    it "converts eengine XML to change YAML to stdout" do
      expect do
        described_class.call(xml_fixture, nil, schema_name, version)
      end.to output(/schema: support_resource_schema/).to_stdout
    end

    it "converts eengine XML and saves to file" do
      require "tempfile"
      Tempfile.create(["output", ".yaml"]) do |f|
        described_class.call(xml_fixture, f.path, schema_name, version)

        # Verify file was written
        content = File.read(f.path)
        expect(content).to include("schema: support_resource_schema")
        expect(content).to include("version: 2")
        expect(content).to include("TYPE text")

        # Verify it can be loaded back
        require "expressir/changes"
        change_schema = Expressir::Changes::SchemaChange.from_file(f.path)
        expect(change_schema.schema).to eq(schema_name)
        expect(change_schema.versions.size).to eq(1)
        expect(change_schema.versions[0].version).to eq(version)
      end
    end

    it "extracts modifications from XML" do
      require "tempfile"
      Tempfile.create(["output", ".yaml"]) do |f|
        result = described_class.call(xml_fixture, f.path, schema_name, version)

        expect(result.versions[0].modifications.size).to eq(1)
        expect(result.versions[0].modifications[0].type).to eq("TYPE")
        expect(result.versions[0].modifications[0].name).to eq("text")
      end
    end

    it "extracts additions from XML including interface items" do
      require "tempfile"
      Tempfile.create(["output", ".yaml"]) do |f|
        result = described_class.call(xml_fixture, f.path, schema_name, version)

        additions = result.versions[0].additions
        expect(additions.size).to eq(3)

        # Check interface items with interfaced.items attribute
        interface_items = additions.select(&:interfaced_items)
        expect(interface_items.size).to eq(2)
        expect(interface_items[0].type).to eq("USE_FROM")
        expect(interface_items[0].name).to eq("geometric_model_schema")
        expect(interface_items[0].interfaced_items).to eq("convex_hexahedron")
        expect(interface_items[1].interfaced_items).to eq("cyclide_segment_solid")

        # Check entity addition without interfaced.items
        entity_item = additions.find { |a| a.type == "ENTITY" }
        expect(entity_item).not_to be_nil
        expect(entity_item.name).to eq("shape_representation")
        expect(entity_item.interfaced_items).to be_nil
      end
    end

    it "extracts deletions from XML including interface items" do
      require "tempfile"
      Tempfile.create(["output", ".yaml"]) do |f|
        result = described_class.call(xml_fixture, f.path, schema_name, version)

        deletions = result.versions[0].deletions
        expect(deletions.size).to eq(1)
        expect(deletions[0].type).to eq("REFERENCE_FROM")
        expect(deletions[0].name).to eq("old_schema")
        expect(deletions[0].interfaced_items).to eq("removed_item")
      end
    end

    it "extracts descriptions at item level (not version level)" do
      require "tempfile"
      Tempfile.create(["output", ".yaml"]) do |f|
        result = described_class.call(xml_fixture, f.path, schema_name, version)

        # Version-level description should be nil
        expect(result.versions[0].description).to be_nil

        # Item-level descriptions should be preserved as an array
        modification = result.versions[0].modifications.find do |m|
          m.name == "text"
        end
        expect(modification.description).to eq(["TYPE text: Underlying Type changed"])
      end
    end

    it "appends to existing change schema" do
      require "tempfile"
      require "expressir/changes"

      Tempfile.create(["output", ".yaml"]) do |f|
        # Create initial file
        initial = Expressir::Changes::SchemaChange.new(schema: schema_name)
        initial.add_or_update_version(1, "Version 1",
                                      { additions: [], modifications: [], deletions: [] })
        initial.to_file(f.path)

        # Convert and append
        result = described_class.call(xml_fixture, f.path, schema_name, 2)

        expect(result.versions.size).to eq(2)
        expect(result.versions[0].version).to eq(1)
        expect(result.versions[1].version).to eq(2)
      end
    end

    it "replaces existing version with same version" do
      require "tempfile"
      require "expressir/changes"

      Tempfile.create(["output", ".yaml"]) do |f|
        # Create initial file
        initial = Expressir::Changes::SchemaChange.new(schema: schema_name)
        initial.add_or_update_version(2, "Old description",
                                      { additions: [], modifications: [], deletions: [] })
        initial.to_file(f.path)

        # Convert and replace
        result = described_class.call(xml_fixture, f.path, schema_name, 2)

        expect(result.versions.size).to eq(1)
        # Version description should be nil (no aggregation)
        expect(result.versions[0].description).to be_nil
        # Item descriptions should be preserved as an array
        modification = result.versions[0].modifications.find do |m|
          m.name == "text"
        end
        expect(modification.description).to be_a(Array)
        expect(modification.description.first).to include("TYPE text")
      end
    end

    context "with ARM mode XML" do
      let(:arm_fixture) do
        File.join(__dir__, "../../fixtures/changes/sample_eengine_arm.xml")
      end

      it "detects and processes ARM mode XML" do
        require "tempfile"
        Tempfile.create(["output", ".yaml"]) do |f|
          result = described_class.call(arm_fixture, f.path, "example_arm", 1)

          additions = result.versions[0].additions
          expect(additions.size).to eq(1)
          expect(additions[0].type).to eq("ENTITY")
          expect(additions[0].name).to eq("Example_Entity")

          modifications = result.versions[0].modifications
          expect(modifications.size).to eq(1)
          expect(modifications[0].type).to eq("ENTITY")
          expect(modifications[0].name).to eq("Modified_Entity")
        end
      end
    end

    context "with MIM mode XML" do
      let(:mim_fixture) do
        File.join(__dir__, "../../fixtures/changes/sample_eengine_mim.xml")
      end

      it "detects and processes MIM mode XML" do
        require "tempfile"
        Tempfile.create(["output", ".yaml"]) do |f|
          result = described_class.call(mim_fixture, f.path, "example_mim", 1)

          additions = result.versions[0].additions
          expect(additions.size).to eq(1)
          expect(additions[0].type).to eq("USE_FROM")
          expect(additions[0].name).to eq("common_schema")
          expect(additions[0].interfaced_items).to eq("identifier")

          deletions = result.versions[0].deletions
          expect(deletions.size).to eq(1)
          expect(deletions[0].type).to eq("TYPE")
          expect(deletions[0].name).to eq("deprecated_type")
        end
      end
    end
  end
end
