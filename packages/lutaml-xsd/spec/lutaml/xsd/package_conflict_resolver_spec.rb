# frozen_string_literal: true

require "spec_helper"

RSpec.describe Lutaml::Xsd::PackageConflictResolver do
  let(:mock_source1) do
    instance_double(
      Lutaml::Xsd::PackageSource,
      package_path: "pkg1.lxr",
      priority: 0,
      conflict_resolution: "keep",
    )
  end

  let(:mock_source2) do
    instance_double(
      Lutaml::Xsd::PackageSource,
      package_path: "pkg2.lxr",
      priority: 10,
      conflict_resolution: "override",
    )
  end

  let(:mock_source3) do
    instance_double(
      Lutaml::Xsd::PackageSource,
      package_path: "pkg3.lxr",
      priority: 5,
      conflict_resolution: "error",
    )
  end

  let(:empty_report) do
    Lutaml::Xsd::ConflictReport.new(
      namespace_conflicts: [],
      type_conflicts: [],
      schema_conflicts: [],
      package_info: [],
    )
  end

  let(:report_with_conflicts) do
    Lutaml::Xsd::ConflictReport.new(
      namespace_conflicts: [
        Lutaml::Xsd::Conflicts::NamespaceConflict.new(
          namespace_uri: "http://example.com/ns",
          package_paths: ["pkg1.lxr", "pkg2.lxr"],
          priorities: [0, 10],
        ),
      ],
      type_conflicts: [],
      schema_conflicts: [],
      package_info: [],
    )
  end

  describe "#initialize" do
    it "accepts conflict report and package sources" do
      resolver = described_class.new(empty_report, [mock_source1, mock_source2])

      expect(resolver.conflict_report).to eq(empty_report)
      expect(resolver.package_sources).to eq([mock_source1, mock_source2])
    end

    it "sorts package sources by priority" do
      resolver = described_class.new(empty_report, [mock_source2, mock_source1])

      # Should be sorted by priority (0 < 10)
      expect(resolver.package_sources).to eq([mock_source1, mock_source2])
    end
  end

  describe "#resolve" do
    context "with no conflicts" do
      it "returns sorted package sources" do
        resolver = described_class.new(empty_report,
                                       [mock_source2, mock_source1])
        result = resolver.resolve

        expect(result).to eq([mock_source1, mock_source2])
      end

      it "does not raise error even with error strategy" do
        resolver = described_class.new(empty_report, [mock_source3])

        expect { resolver.resolve }.not_to raise_error
      end
    end

    context "with conflicts and 'keep' strategy" do
      it "returns sorted sources" do
        resolver = described_class.new(report_with_conflicts,
                                       [mock_source1, mock_source2])
        result = resolver.resolve

        expect(result).to eq([mock_source1, mock_source2])
      end
    end

    context "with conflicts and 'override' strategy" do
      it "returns sorted sources" do
        resolver = described_class.new(report_with_conflicts,
                                       [mock_source1, mock_source2])
        result = resolver.resolve

        expect(result).to eq([mock_source1, mock_source2])
      end
    end

    context "with conflicts and 'error' strategy" do
      it "raises PackageMergeError" do
        resolver = described_class.new(report_with_conflicts, [mock_source3])

        expect do
          resolver.resolve
        end.to raise_error(Lutaml::Xsd::PackageMergeError) do |error|
          expect(error.message).to include("Conflicts detected with 'error' resolution strategy")
          expect(error.conflict_report).to eq(report_with_conflicts)
          expect(error.error_strategy_sources).to eq([mock_source3])
        end
      end

      it "includes conflict report in error" do
        resolver = described_class.new(report_with_conflicts, [mock_source3])

        expect { resolver.resolve }.to raise_error do |error|
          expect(error.conflict_report.has_conflicts?).to be true
          expect(error.conflict_report.namespace_conflicts.size).to eq(1)
        end
      end
    end

    context "with mixed strategies and conflicts" do
      it "raises error if any source has error strategy" do
        resolver = described_class.new(
          report_with_conflicts,
          [mock_source1, mock_source3, mock_source2],
        )

        expect { resolver.resolve }.to raise_error(Lutaml::Xsd::PackageMergeError)
      end
    end
  end

  describe "#resolve_conflict" do
    let(:namespace_conflict) do
      Lutaml::Xsd::Conflicts::NamespaceConflict.from_sources(
        namespace_uri: "http://example.com/ns",
        sources: [mock_source1, mock_source2],
      )
    end

    let(:type_conflict) do
      Lutaml::Xsd::Conflicts::TypeConflict.from_sources(
        namespace_uri: "http://example.com/ns",
        type_name: "PersonType",
        sources: [mock_source1, mock_source2],
      )
    end

    let(:schema_conflict) do
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
      )
    end

    context "with namespace conflict" do
      it "resolves using 'keep' strategy (first wins)" do
        resolver = described_class.new(empty_report,
                                       [mock_source1, mock_source2])
        winner = resolver.resolve_conflict(namespace_conflict)

        expect(winner).to eq(mock_source1)
      end

      it "resolves using 'override' strategy (last wins)" do
        mock_override1 = instance_double(
          Lutaml::Xsd::PackageSource,
          package_path: "pkg1.lxr",
          priority: 0,
          conflict_resolution: "override",
        )
        mock_override2 = instance_double(
          Lutaml::Xsd::PackageSource,
          package_path: "pkg2.lxr",
          priority: 10,
          conflict_resolution: "override",
        )

        conflict = Lutaml::Xsd::Conflicts::NamespaceConflict.from_sources(
          namespace_uri: "http://example.com/ns",
          sources: [mock_override1, mock_override2],
        )

        resolver = described_class.new(empty_report,
                                       [mock_override1, mock_override2])
        winner = resolver.resolve_conflict(conflict)

        expect(winner).to eq(mock_override2)
      end
    end

    context "with type conflict" do
      it "resolves using priority and strategy" do
        resolver = described_class.new(empty_report,
                                       [mock_source1, mock_source2])
        winner = resolver.resolve_conflict(type_conflict)

        expect(winner).to eq(mock_source1)
      end
    end

    context "with schema conflict" do
      it "resolves using priority from source files" do
        resolver = described_class.new(empty_report,
                                       [mock_source1, mock_source2])
        winner = resolver.resolve_conflict(schema_conflict)

        expect(winner).to eq(mock_source1)
      end
    end

    context "with error strategy" do
      it "raises PackageMergeError" do
        conflict_with_error = Lutaml::Xsd::Conflicts::NamespaceConflict.from_sources(
          namespace_uri: "http://example.com/ns",
          sources: [mock_source3],
        )

        resolver = described_class.new(report_with_conflicts, [mock_source3])

        expect do
          resolver.resolve_conflict(conflict_with_error)
        end.to raise_error(
          Lutaml::Xsd::PackageMergeError,
          /Conflict with 'error' strategy/,
        )
      end
    end
  end

  describe "resolution priority" do
    it "uses lowest priority number as highest priority" do
      sources = [
        instance_double(
          Lutaml::Xsd::PackageSource,
          priority: 100,
          conflict_resolution: "keep",
        ),
        instance_double(
          Lutaml::Xsd::PackageSource,
          priority: 1,
          conflict_resolution: "keep",
        ),
        instance_double(
          Lutaml::Xsd::PackageSource,
          priority: 50,
          conflict_resolution: "keep",
        ),
      ]

      resolver = described_class.new(empty_report, sources)
      sorted = resolver.package_sources

      expect(sorted.map(&:priority)).to eq([1, 50, 100])
    end
  end
end
