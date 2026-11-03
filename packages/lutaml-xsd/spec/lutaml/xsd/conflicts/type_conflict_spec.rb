# frozen_string_literal: true

require "spec_helper"

RSpec.describe Lutaml::Xsd::Conflicts::TypeConflict do
  let(:namespace_uri) { "http://example.com/schema" }
  let(:type_name) { "PersonType" }
  let(:package_paths) { ["package1.lxr", "package2.lxr"] }
  let(:priorities) { [0, 10] }

  let(:mock_source1) do
    instance_double(
      Lutaml::Xsd::PackageSource,
      package_path: package_paths[0],
      priority: priorities[0],
    )
  end

  let(:mock_source2) do
    instance_double(
      Lutaml::Xsd::PackageSource,
      package_path: package_paths[1],
      priority: priorities[1],
    )
  end

  describe ".from_sources" do
    it "creates conflict from PackageSource objects" do
      conflict = described_class.from_sources(
        namespace_uri: namespace_uri,
        type_name: type_name,
        sources: [mock_source1, mock_source2],
      )

      expect(conflict.namespace_uri).to eq(namespace_uri)
      expect(conflict.type_name).to eq(type_name)
      expect(conflict.package_paths).to eq(package_paths)
      expect(conflict.priorities).to eq(priorities)
      expect(conflict.sources).to eq([mock_source1, mock_source2])
    end

    it "extracts paths and priorities from sources" do
      conflict = described_class.from_sources(
        namespace_uri: namespace_uri,
        type_name: type_name,
        sources: [mock_source1],
      )

      expect(conflict.package_paths).to eq([package_paths[0]])
      expect(conflict.priorities).to eq([priorities[0]])
    end
  end

  describe "#qualified_name" do
    it "returns Clark notation qualified name" do
      conflict = described_class.new(
        namespace_uri: namespace_uri,
        type_name: type_name,
        package_paths: package_paths,
        priorities: priorities,
      )

      expect(conflict.qualified_name).to eq("{http://example.com/schema}PersonType")
    end
  end

  describe "#conflict_count" do
    it "returns number of conflicting packages" do
      conflict = described_class.new(
        namespace_uri: namespace_uri,
        type_name: type_name,
        package_paths: package_paths,
        priorities: priorities,
      )

      expect(conflict.conflict_count).to eq(2)
    end

    it "handles single package" do
      conflict = described_class.new(
        namespace_uri: namespace_uri,
        type_name: type_name,
        package_paths: [package_paths[0]],
        priorities: [priorities[0]],
      )

      expect(conflict.conflict_count).to eq(1)
    end
  end

  describe "#highest_priority_source" do
    it "returns source with lowest priority number" do
      conflict = described_class.from_sources(
        namespace_uri: namespace_uri,
        type_name: type_name,
        sources: [mock_source1, mock_source2],
      )

      expect(conflict.highest_priority_source).to eq(mock_source1)
    end

    it "returns nil when sources not set" do
      conflict = described_class.new(
        namespace_uri: namespace_uri,
        type_name: type_name,
        package_paths: package_paths,
        priorities: priorities,
      )

      expect(conflict.highest_priority_source).to be_nil
    end
  end

  describe "#to_s" do
    it "returns human-readable summary" do
      conflict = described_class.new(
        namespace_uri: namespace_uri,
        type_name: type_name,
        package_paths: package_paths,
        priorities: priorities,
      )

      expect(conflict.to_s).to eq(
        "Type 'PersonType' in '{http://example.com/schema}' defined in 2 packages",
      )
    end
  end

  describe "#detailed_description" do
    it "returns detailed conflict information" do
      conflict = described_class.new(
        namespace_uri: namespace_uri,
        type_name: type_name,
        package_paths: package_paths,
        priorities: priorities,
      )

      description = conflict.detailed_description
      expect(description).to include("Type Name Conflict:")
      expect(description).to include("Type: {http://example.com/schema}PersonType")
      expect(description).to include("Defined in packages:")
      expect(description).to include("- package1.lxr (priority: 0)")
      expect(description).to include("- package2.lxr (priority: 10)")
    end

    it "formats multiple packages properly" do
      conflict = described_class.new(
        namespace_uri: namespace_uri,
        type_name: type_name,
        package_paths: ["pkg1.lxr", "pkg2.lxr", "pkg3.lxr"],
        priorities: [0, 5, 10],
      )

      description = conflict.detailed_description
      expect(description).to include("- pkg1.lxr (priority: 0)")
      expect(description).to include("- pkg2.lxr (priority: 5)")
      expect(description).to include("- pkg3.lxr (priority: 10)")
    end
  end

  describe "serialization" do
    let(:conflict) do
      described_class.new(
        namespace_uri: namespace_uri,
        type_name: type_name,
        package_paths: package_paths,
        priorities: priorities,
      )
    end

    describe "#to_hash" do
      it "converts to hash" do
        hash = conflict.to_hash

        expect(hash["namespace_uri"]).to eq(namespace_uri)
        expect(hash["type_name"]).to eq(type_name)
        expect(hash["package_paths"]).to eq(package_paths)
        expect(hash["priorities"]).to eq(priorities)
      end

      it "does not include runtime sources" do
        conflict.sources = [mock_source1, mock_source2]
        hash = conflict.to_hash

        expect(hash).not_to have_key("sources")
      end
    end

    describe "#to_yaml" do
      it "serializes to YAML" do
        yaml = conflict.to_yaml

        expect(yaml).to include("namespace_uri: http://example.com/schema")
        expect(yaml).to include("type_name: PersonType")
        expect(yaml).to include("package_paths:")
        expect(yaml).to include("- package1.lxr")
        expect(yaml).to include("- package2.lxr")
        expect(yaml).to include("priorities:")
        expect(yaml).to include("- 0")
        expect(yaml).to include("- 10")
      end

      it "round-trips through YAML" do
        yaml = conflict.to_yaml
        restored = described_class.from_yaml(yaml)

        expect(restored.namespace_uri).to eq(namespace_uri)
        expect(restored.type_name).to eq(type_name)
        expect(restored.package_paths).to eq(package_paths)
        expect(restored.priorities).to eq(priorities)
      end
    end

    describe "#to_json" do
      it "serializes to JSON" do
        json = conflict.to_json

        expect(json).to include('"namespace_uri":"http://example.com/schema"')
        expect(json).to include('"type_name":"PersonType"')
        expect(json).to include('"package_paths":["package1.lxr","package2.lxr"]')
        expect(json).to include('"priorities":[0,10]')
      end

      it "round-trips through JSON" do
        json = conflict.to_json
        restored = described_class.from_json(json)

        expect(restored.namespace_uri).to eq(namespace_uri)
        expect(restored.type_name).to eq(type_name)
        expect(restored.package_paths).to eq(package_paths)
        expect(restored.priorities).to eq(priorities)
      end
    end
  end
end
