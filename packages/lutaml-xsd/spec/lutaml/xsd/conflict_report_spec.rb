# frozen_string_literal: true

require "spec_helper"

RSpec.describe Lutaml::Xsd::ConflictReport do
  describe Lutaml::Xsd::PackageInfo do
    let(:package_path) { "package1.lxr" }
    let(:priority) { 5 }
    let(:conflict_resolution) { "keep" }

    describe "initialization" do
      it "creates package info with all attributes" do
        info = described_class.new(
          package_path: package_path,
          priority: priority,
          conflict_resolution: conflict_resolution,
        )

        expect(info.package_path).to eq(package_path)
        expect(info.priority).to eq(priority)
        expect(info.conflict_resolution).to eq(conflict_resolution)
      end
    end

    describe ".from_source" do
      it "creates from PackageSource object" do
        mock_source = instance_double(
          Lutaml::Xsd::PackageSource,
          package_path: package_path,
          priority: priority,
          conflict_resolution: conflict_resolution,
        )

        info = described_class.from_source(mock_source)

        expect(info.package_path).to eq(package_path)
        expect(info.priority).to eq(priority)
        expect(info.conflict_resolution).to eq(conflict_resolution)
      end
    end

    describe "serialization" do
      let(:info) do
        described_class.new(
          package_path: package_path,
          priority: priority,
          conflict_resolution: conflict_resolution,
        )
      end

      it "converts to hash" do
        hash = info.to_hash

        expect(hash["package_path"]).to eq(package_path)
        expect(hash["priority"]).to eq(priority)
        expect(hash["conflict_resolution"]).to eq(conflict_resolution)
      end

      it "round-trips through YAML" do
        yaml = info.to_yaml
        restored = described_class.from_yaml(yaml)

        expect(restored.package_path).to eq(package_path)
        expect(restored.priority).to eq(priority)
        expect(restored.conflict_resolution).to eq(conflict_resolution)
      end

      it "round-trips through JSON" do
        json = info.to_json
        restored = described_class.from_json(json)

        expect(restored.package_path).to eq(package_path)
        expect(restored.priority).to eq(priority)
        expect(restored.conflict_resolution).to eq(conflict_resolution)
      end
    end
  end

  describe Lutaml::Xsd::ConflictReport do
    let(:namespace_conflicts) do
      [
        Lutaml::Xsd::Conflicts::NamespaceConflict.new(
          namespace_uri: "http://example.com/ns1",
          package_paths: ["pkg1.lxr", "pkg2.lxr"],
          priorities: [0, 10],
        ),
      ]
    end

    let(:type_conflicts) do
      [
        Lutaml::Xsd::Conflicts::TypeConflict.new(
          namespace_uri: "http://example.com/ns1",
          type_name: "PersonType",
          package_paths: ["pkg1.lxr", "pkg2.lxr"],
          priorities: [0, 10],
        ),
      ]
    end

    let(:schema_conflicts) do
      [
        Lutaml::Xsd::Conflicts::SchemaConflict.new(
          schema_basename: "person.xsd",
          source_files: [
            Lutaml::Xsd::Conflicts::SchemaFileSource.new(
              package_path: "pkg1.lxr",
              schema_file: "schemas/person.xsd",
              priority: 0,
            ),
            Lutaml::Xsd::Conflicts::SchemaFileSource.new(
              package_path: "pkg2.lxr",
              schema_file: "xsd/person.xsd",
              priority: 10,
            ),
          ],
        ),
      ]
    end

    let(:mock_sources) do
      [
        instance_double(
          Lutaml::Xsd::PackageSource,
          package_path: "pkg1.lxr",
          priority: 0,
          conflict_resolution: "keep",
        ),
        instance_double(
          Lutaml::Xsd::PackageSource,
          package_path: "pkg2.lxr",
          priority: 10,
          conflict_resolution: "override",
        ),
      ]
    end

    describe ".from_conflicts" do
      it "creates report from conflict arrays" do
        report = described_class.from_conflicts(
          namespace_conflicts: namespace_conflicts,
          type_conflicts: type_conflicts,
          schema_conflicts: schema_conflicts,
          package_sources: mock_sources,
        )

        expect(report.namespace_conflicts).to eq(namespace_conflicts)
        expect(report.type_conflicts).to eq(type_conflicts)
        expect(report.schema_conflicts).to eq(schema_conflicts)
        expect(report.package_sources).to eq(mock_sources)
        expect(report.package_info.size).to eq(2)
      end

      it "creates PackageInfo from sources" do
        report = described_class.from_conflicts(
          namespace_conflicts: [],
          type_conflicts: [],
          schema_conflicts: [],
          package_sources: mock_sources,
        )

        expect(report.package_info[0].package_path).to eq("pkg1.lxr")
        expect(report.package_info[0].priority).to eq(0)
        expect(report.package_info[0].conflict_resolution).to eq("keep")
      end
    end

    describe "#has_conflicts?" do
      it "returns true when conflicts exist" do
        report = described_class.new(
          namespace_conflicts: namespace_conflicts,
          type_conflicts: [],
          schema_conflicts: [],
          package_info: [],
        )

        expect(report.has_conflicts?).to be true
      end

      it "returns false when no conflicts" do
        report = described_class.new(
          namespace_conflicts: [],
          type_conflicts: [],
          schema_conflicts: [],
          package_info: [],
        )

        expect(report.has_conflicts?).to be false
      end
    end

    describe "#total_conflicts" do
      it "counts all conflict types" do
        report = described_class.new(
          namespace_conflicts: namespace_conflicts,
          type_conflicts: type_conflicts,
          schema_conflicts: schema_conflicts,
          package_info: [],
        )

        expect(report.total_conflicts).to eq(3)
      end

      it "returns zero when no conflicts" do
        report = described_class.new(
          namespace_conflicts: [],
          type_conflicts: [],
          schema_conflicts: [],
          package_info: [],
        )

        expect(report.total_conflicts).to eq(0)
      end
    end

    describe "#all_conflicts" do
      it "returns array of all conflicts" do
        report = described_class.new(
          namespace_conflicts: namespace_conflicts,
          type_conflicts: type_conflicts,
          schema_conflicts: schema_conflicts,
          package_info: [],
        )

        all = report.all_conflicts
        expect(all.size).to eq(3)
        expect(all).to include(*namespace_conflicts)
        expect(all).to include(*type_conflicts)
        expect(all).to include(*schema_conflicts)
      end
    end

    describe "#to_s" do
      it "returns success message when no conflicts" do
        report = described_class.new(
          namespace_conflicts: [],
          type_conflicts: [],
          schema_conflicts: [],
          package_info: [],
        )

        expect(report.to_s).to eq("✓ No conflicts detected")
      end

      it "formats conflict report with all sections" do
        info = [
          Lutaml::Xsd::PackageInfo.new(
            package_path: "pkg1.lxr",
            priority: 0,
            conflict_resolution: "keep",
          ),
          Lutaml::Xsd::PackageInfo.new(
            package_path: "pkg2.lxr",
            priority: 10,
            conflict_resolution: "override",
          ),
        ]

        report = described_class.new(
          namespace_conflicts: namespace_conflicts,
          type_conflicts: type_conflicts,
          schema_conflicts: schema_conflicts,
          package_info: info,
        )

        output = report.to_s

        # Check header
        expect(output).to include("❌ Package Merge Conflicts Detected")
        expect(output).to include("Total conflicts: 3")
        expect(output).to include("- Namespace conflicts: 1")
        expect(output).to include("- Type conflicts: 1")
        expect(output).to include("- Schema conflicts: 1")

        # Check conflict sections
        expect(output).to include("Namespace URI Conflicts:")
        expect(output).to include("Type Name Conflicts:")
        expect(output).to include("Schema File Conflicts:")

        # Check resolution strategies
        expect(output).to include("Resolution Strategies:")
        expect(output).to include("Package: pkg1.lxr")
        expect(output).to include("Priority: 0")
        expect(output).to include("Strategy: keep")

        # Check guidance
        expect(output).to include("💡 To resolve conflicts:")
        expect(output).to include("Update package priorities")
      end

      it "formats namespace conflicts section" do
        report = described_class.new(
          namespace_conflicts: namespace_conflicts,
          type_conflicts: [],
          schema_conflicts: [],
          package_info: [],
        )

        output = report.to_s
        expect(output).to include("Namespace URI Conflicts:")
        expect(output).to include("http://example.com/ns1")
        expect(output).to include("pkg1.lxr")
        expect(output).to include("pkg2.lxr")
      end

      it "formats type conflicts section" do
        report = described_class.new(
          namespace_conflicts: [],
          type_conflicts: type_conflicts,
          schema_conflicts: [],
          package_info: [],
        )

        output = report.to_s
        expect(output).to include("Type Name Conflicts:")
        expect(output).to include("PersonType")
        expect(output).to include("http://example.com/ns1")
      end

      it "formats schema conflicts section" do
        report = described_class.new(
          namespace_conflicts: [],
          type_conflicts: [],
          schema_conflicts: schema_conflicts,
          package_info: [],
        )

        output = report.to_s
        expect(output).to include("Schema File Conflicts:")
        expect(output).to include("person.xsd")
        expect(output).to include("schemas/person.xsd")
      end
    end

    describe "serialization" do
      let(:info) do
        [
          Lutaml::Xsd::PackageInfo.new(
            package_path: "pkg1.lxr",
            priority: 0,
            conflict_resolution: "keep",
          ),
        ]
      end

      let(:report) do
        described_class.new(
          namespace_conflicts: namespace_conflicts,
          type_conflicts: type_conflicts,
          schema_conflicts: schema_conflicts,
          package_info: info,
        )
      end

      describe "#to_hash" do
        it "converts report to hash" do
          hash = report.to_hash

          expect(hash["namespace_conflicts"]).to be_an(Array)
          expect(hash["type_conflicts"]).to be_an(Array)
          expect(hash["schema_conflicts"]).to be_an(Array)
          expect(hash["package_info"]).to be_an(Array)
        end

        it "does not include runtime package_sources" do
          report.package_sources = mock_sources
          hash = report.to_hash

          expect(hash).not_to have_key("package_sources")
        end
      end

      describe "#to_yaml" do
        it "serializes to YAML" do
          yaml = report.to_yaml

          expect(yaml).to include("namespace_conflicts:")
          expect(yaml).to include("type_conflicts:")
          expect(yaml).to include("schema_conflicts:")
          expect(yaml).to include("package_info:")
        end

        it "round-trips through YAML" do
          yaml = report.to_yaml
          restored = described_class.from_yaml(yaml)

          expect(restored.namespace_conflicts.size).to eq(1)
          expect(restored.type_conflicts.size).to eq(1)
          expect(restored.schema_conflicts.size).to eq(1)
          expect(restored.package_info.size).to eq(1)
        end
      end

      describe "#to_json" do
        it "serializes to JSON" do
          json = report.to_json

          expect(json).to include('"namespace_conflicts":[')
          expect(json).to include('"type_conflicts":[')
          expect(json).to include('"schema_conflicts":[')
          expect(json).to include('"package_info":[')
        end

        it "round-trips through JSON" do
          json = report.to_json
          restored = described_class.from_json(json)

          expect(restored.namespace_conflicts.size).to eq(1)
          expect(restored.type_conflicts.size).to eq(1)
          expect(restored.schema_conflicts.size).to eq(1)
          expect(restored.package_info.size).to eq(1)
        end
      end
    end
  end
end
