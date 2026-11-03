# frozen_string_literal: true

require "spec_helper"

RSpec.describe Lutaml::Xsd::PackageConflictDetector do
  let(:config1) do
    Lutaml::Xsd::BasePackageConfig.new(
      package: "pkg1.lxr",
      priority: 0,
      conflict_resolution: "keep",
    )
  end

  let(:config2) do
    Lutaml::Xsd::BasePackageConfig.new(
      package: "pkg2.lxr",
      priority: 10,
      conflict_resolution: "override",
    )
  end

  let(:mock_repo1) do
    instance_double(
      Lutaml::Xsd::SchemaRepository,
      files: ["schemas/person.xsd", "schemas/company.xsd"],
      namespace_mappings: [],
    )
  end

  let(:mock_repo2) do
    instance_double(
      Lutaml::Xsd::SchemaRepository,
      files: ["xsd/person.xsd", "xsd/address.xsd"],
      namespace_mappings: [],
    )
  end

  before do
    allow(File).to receive(:exist?).with("pkg1.lxr").and_return(true)
    allow(File).to receive(:exist?).with("pkg2.lxr").and_return(true)
    allow(Lutaml::Xsd::SchemaRepository).to receive(:from_package)
      .with("pkg1.lxr").and_return(mock_repo1)
    allow(Lutaml::Xsd::SchemaRepository).to receive(:from_package)
      .with("pkg2.lxr").and_return(mock_repo2)
  end

  describe "#initialize" do
    it "accepts package configs array" do
      detector = described_class.new([config1, config2])
      expect(detector.package_configs).to eq([config1, config2])
    end
  end

  describe "#detect_conflicts" do
    context "with no conflicts" do
      let(:mock_repo1_no_conflict) do
        instance_double(
          Lutaml::Xsd::SchemaRepository,
          files: ["schemas/person.xsd"],
          namespace_mappings: [],
        )
      end

      let(:mock_repo2_no_conflict) do
        instance_double(
          Lutaml::Xsd::SchemaRepository,
          files: ["schemas/company.xsd"],
          namespace_mappings: [],
        )
      end

      before do
        allow(Lutaml::Xsd::SchemaRepository).to receive(:from_package)
          .with("pkg1.lxr").and_return(mock_repo1_no_conflict)
        allow(Lutaml::Xsd::SchemaRepository).to receive(:from_package)
          .with("pkg2.lxr").and_return(mock_repo2_no_conflict)

        allow(mock_repo1_no_conflict).to receive(:all_namespaces).and_return(["http://example.com/ns1"])
        allow(mock_repo2_no_conflict).to receive(:all_namespaces).and_return(["http://example.com/ns2"])
        allow(mock_repo1_no_conflict).to receive(:all_type_names).and_return(["Type1"])
        allow(mock_repo2_no_conflict).to receive(:all_type_names).and_return(["Type2"])
      end

      it "returns report with no conflicts" do
        detector = described_class.new([config1, config2])
        report = detector.detect_conflicts

        expect(report).to be_a(Lutaml::Xsd::ConflictReport)
        expect(report.has_conflicts?).to be false
        expect(report.total_conflicts).to eq(0)
      end

      it "includes package info" do
        detector = described_class.new([config1, config2])
        report = detector.detect_conflicts

        expect(report.package_info.size).to eq(2)
        expect(report.package_info[0].package_path).to eq("pkg1.lxr")
        expect(report.package_info[1].package_path).to eq("pkg2.lxr")
      end
    end

    context "with namespace conflicts" do
      before do
        shared_ns = "http://example.com/shared"
        allow(mock_repo1).to receive(:all_namespaces).and_return([shared_ns])
        allow(mock_repo2).to receive(:all_namespaces).and_return([shared_ns])
        allow(mock_repo1).to receive(:all_type_names).with(namespace: shared_ns).and_return([])
        allow(mock_repo2).to receive(:all_type_names).with(namespace: shared_ns).and_return([])
      end

      it "detects namespace URI conflicts" do
        detector = described_class.new([config1, config2])
        report = detector.detect_conflicts

        expect(report.namespace_conflicts.size).to eq(1)
        conflict = report.namespace_conflicts.first
        expect(conflict.namespace_uri).to eq("http://example.com/shared")
        expect(conflict.package_paths).to contain_exactly("pkg1.lxr",
                                                          "pkg2.lxr")
      end
    end

    context "with type conflicts" do
      before do
        shared_ns = "http://example.com/ns1"
        allow(mock_repo1).to receive(:all_namespaces).and_return([shared_ns])
        allow(mock_repo2).to receive(:all_namespaces).and_return([shared_ns])
        allow(mock_repo1).to receive(:all_type_names)
          .with(namespace: shared_ns).and_return(["PersonType", "UniqueType1"])
        allow(mock_repo2).to receive(:all_type_names)
          .with(namespace: shared_ns).and_return(["PersonType", "UniqueType2"])
      end

      it "detects type name conflicts" do
        detector = described_class.new([config1, config2])
        report = detector.detect_conflicts

        expect(report.type_conflicts.size).to eq(1)
        conflict = report.type_conflicts.first
        expect(conflict.type_name).to eq("PersonType")
        expect(conflict.namespace_uri).to eq("http://example.com/ns1")
        expect(conflict.package_paths).to contain_exactly("pkg1.lxr",
                                                          "pkg2.lxr")
      end
    end

    context "with schema conflicts" do
      before do
        allow(mock_repo1).to receive(:all_namespaces).and_return([])
        allow(mock_repo2).to receive(:all_namespaces).and_return([])
      end

      it "detects schema file conflicts by basename" do
        detector = described_class.new([config1, config2])
        report = detector.detect_conflicts

        expect(report.schema_conflicts.size).to eq(1)
        conflict = report.schema_conflicts.first
        expect(conflict.schema_basename).to eq("person.xsd")
        expect(conflict.source_files.size).to eq(2)
        expect(conflict.file_paths).to contain_exactly(
          "schemas/person.xsd",
          "xsd/person.xsd",
        )
      end
    end

    context "with multiple conflict types" do
      before do
        shared_ns = "http://example.com/shared"
        allow(mock_repo1).to receive(:all_namespaces).and_return([shared_ns])
        allow(mock_repo2).to receive(:all_namespaces).and_return([shared_ns])
        allow(mock_repo1).to receive(:all_type_names)
          .with(namespace: shared_ns).and_return(["SharedType"])
        allow(mock_repo2).to receive(:all_type_names)
          .with(namespace: shared_ns).and_return(["SharedType"])
      end

      it "detects all types of conflicts" do
        detector = described_class.new([config1, config2])
        report = detector.detect_conflicts

        expect(report.namespace_conflicts.size).to eq(1)
        expect(report.type_conflicts.size).to eq(1)
        expect(report.schema_conflicts.size).to eq(1)
        expect(report.total_conflicts).to eq(3)
      end
    end

    context "with namespace remapping" do
      let(:config_with_remap) do
        Lutaml::Xsd::BasePackageConfig.new(
          package: "pkg1.lxr",
          priority: 0,
          conflict_resolution: "keep",
          namespace_remapping: [
            Lutaml::Xsd::NamespaceUriRemapping.new(
              from_uri: "http://old.example.com/ns",
              to_uri: "http://new.example.com/ns",
            ),
          ],
        )
      end

      let(:mock_ns_mapping) do
        instance_double(
          Lutaml::Xsd::NamespaceMapping,
          prefix: "ex",
          uri: "http://old.example.com/ns",
        )
      end

      before do
        allow(mock_repo1).to receive(:namespace_mappings).and_return([mock_ns_mapping])
        allow(mock_repo1).to receive(:schema_location_mappings).and_return([])
        allow(mock_repo1).to receive(:instance_variable_get).with(:@parsed_schemas).and_return(Lutaml::Store::BasicStore.new(adapter_type: :memory))

        # Mock the new repository creation
        allow(Lutaml::Xsd::SchemaRepository).to receive(:new).and_call_original
        allow(Lutaml::Xsd::NamespaceMapping).to receive(:new).and_call_original

        allow(mock_repo1).to receive(:all_namespaces).and_return([])
        allow(mock_repo2).to receive(:all_namespaces).and_return([])
      end

      it "applies namespace remapping during load" do
        detector = described_class.new([config_with_remap, config2])
        report = detector.detect_conflicts

        # Should not raise errors and complete successfully
        expect(report).to be_a(Lutaml::Xsd::ConflictReport)
      end
    end

    context "with missing package file" do
      before do
        allow(File).to receive(:exist?).with("missing.lxr").and_return(false)
      end

      it "raises ConfigurationError" do
        bad_config = Lutaml::Xsd::BasePackageConfig.new(
          package: "missing.lxr",
          priority: 0,
        )

        detector = described_class.new([bad_config])

        expect { detector.detect_conflicts }.to raise_error(
          Lutaml::Xsd::ConfigurationError,
          /Base package not found: missing.lxr/,
        )
      end
    end
  end

  describe "private methods behavior" do
    before do
      allow(mock_repo1).to receive(:all_namespaces).and_return(["http://example.com/ns1"])
      allow(mock_repo2).to receive(:all_namespaces).and_return(["http://example.com/ns1"])
      allow(mock_repo1).to receive(:all_type_names).and_return([])
      allow(mock_repo2).to receive(:all_type_names).and_return([])
    end

    it "creates PackageSource objects" do
      detector = described_class.new([config1, config2])
      report = detector.detect_conflicts

      expect(report.package_sources).to all(be_a(Lutaml::Xsd::PackageSource))
      expect(report.package_sources.size).to eq(2)
    end

    it "preserves package priorities" do
      detector = described_class.new([config1, config2])
      report = detector.detect_conflicts

      sources = report.package_sources
      expect(sources[0].priority).to eq(0)
      expect(sources[1].priority).to eq(10)
    end

    it "preserves conflict resolution strategies" do
      detector = described_class.new([config1, config2])
      report = detector.detect_conflicts

      sources = report.package_sources
      expect(sources[0].conflict_resolution).to eq("keep")
      expect(sources[1].conflict_resolution).to eq("override")
    end
  end
end
