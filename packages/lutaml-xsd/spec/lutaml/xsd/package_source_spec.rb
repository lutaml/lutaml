# frozen_string_literal: true

require "spec_helper"
require "lutaml/xsd/package_source"

RSpec.describe Lutaml::Xsd::PackageSource do
  let(:config) do
    Lutaml::Xsd::BasePackageConfig.new(
      package: "path/to/package.lxr",
      priority: 5,
      conflict_resolution: "keep",
      namespace_remapping: [
        Lutaml::Xsd::NamespaceUriRemapping.new(
          from_uri: "http://example.com/old",
          to_uri: "http://example.com/new",
        ),
      ],
      exclude_schemas: ["test/**/*.xsd"],
    )
  end

  let(:repository) do
    double("SchemaRepository",
           all_namespaces: [
             "http://example.com/ns1",
             "http://example.com/ns2",
           ],
           files: ["schema1.xsd", "schema2.xsd"])
  end

  let(:package_source) do
    described_class.new(
      package_path: "path/to/package.lxr",
      config: config,
      repository: repository,
    )
  end

  describe "#initialize" do
    it "sets package_path" do
      expect(package_source.package_path).to eq("path/to/package.lxr")
    end

    it "sets config" do
      expect(package_source.config).to eq(config)
    end

    it "sets repository" do
      expect(package_source.repository).to eq(repository)
    end
  end

  describe "#priority" do
    it "delegates to config" do
      expect(package_source.priority).to eq(5)
    end
  end

  describe "#conflict_resolution" do
    it "delegates to config" do
      expect(package_source.conflict_resolution).to eq("keep")
    end
  end

  describe "#namespaces" do
    it "delegates to repository" do
      expect(package_source.namespaces).to eq(
        ["http://example.com/ns1", "http://example.com/ns2"],
      )
    end

    it "calls all_namespaces on repository" do
      expect(repository).to receive(:all_namespaces)
      package_source.namespaces
    end
  end

  describe "#types_in_namespace" do
    it "delegates to repository" do
      allow(repository).to receive(:all_type_names)
        .with(namespace: "http://example.com/ns1")
        .and_return(["Type1", "Type2"])

      result = package_source.types_in_namespace("http://example.com/ns1")

      expect(result).to eq(["Type1", "Type2"])
    end

    it "passes namespace parameter correctly" do
      expect(repository).to receive(:all_type_names)
        .with(namespace: "http://example.com/test")

      package_source.types_in_namespace("http://example.com/test")
    end
  end

  describe "#schema_files" do
    it "delegates to repository.files" do
      expect(package_source.schema_files).to eq(
        ["schema1.xsd", "schema2.xsd"],
      )
    end

    context "when repository.files is nil" do
      let(:repository) do
        double("SchemaRepository",
               all_namespaces: [],
               files: nil)
      end

      it "returns empty array" do
        expect(package_source.schema_files).to eq([])
      end
    end
  end

  describe "#namespace_remapping" do
    it "returns remapping rules from config" do
      remapping = package_source.namespace_remapping

      expect(remapping.size).to eq(1)
      expect(remapping.first.from_uri).to eq("http://example.com/old")
      expect(remapping.first.to_uri).to eq("http://example.com/new")
    end

    context "when config has no remapping" do
      let(:config) do
        Lutaml::Xsd::BasePackageConfig.new(
          package: "path/to/package.lxr",
        )
      end

      it "returns empty array" do
        expect(package_source.namespace_remapping).to eq([])
      end
    end
  end

  describe "#include_schema?" do
    it "delegates to config" do
      expect(config).to receive(:include_schema?)
        .with("test/schema.xsd")

      package_source.include_schema?("test/schema.xsd")
    end

    it "returns config's result for excluded schema" do
      expect(package_source.include_schema?("test/schema.xsd")).to be false
    end

    it "returns config's result for included schema" do
      expect(package_source.include_schema?("src/schema.xsd")).to be true
    end
  end

  describe "#to_s" do
    it "returns friendly string representation" do
      result = package_source.to_s

      expect(result).to eq("PackageSource(package.lxr, priority=5)")
    end

    it "uses basename of package path" do
      source = described_class.new(
        package_path: "/long/path/to/my_package.lxr",
        config: config,
        repository: repository,
      )

      expect(source.to_s).to eq("PackageSource(my_package.lxr, priority=5)")
    end
  end

  describe "#inspect" do
    it "returns detailed inspection string" do
      result = package_source.inspect

      expect(result).to include("PackageSource")
      expect(result).to include('path="path/to/package.lxr"')
      expect(result).to include("priority=5")
      expect(result).to include("strategy=keep")
      expect(result).to include("namespaces=2")
    end
  end

  describe "integration with real config objects" do
    let(:real_config) do
      Lutaml::Xsd::BasePackageConfig.new(
        package: "test.lxr",
        priority: 10,
        conflict_resolution: "override",
        namespace_remapping: [
          Lutaml::Xsd::NamespaceUriRemapping.new(
            from_uri: "http://old.example.com/",
            to_uri: "http://new.example.com/",
          ),
        ],
        exclude_schemas: ["*.tmp.xsd"],
        include_only_schemas: ["core/**/*.xsd"],
      )
    end

    let(:real_repository) do
      double("SchemaRepository",
             all_namespaces: ["http://new.example.com/"],
             files: ["core/schema.xsd"])
    end

    let(:real_source) do
      described_class.new(
        package_path: "test.lxr",
        config: real_config,
        repository: real_repository,
      )
    end

    it "works with complete configuration" do
      expect(real_source.priority).to eq(10)
      expect(real_source.conflict_resolution).to eq("override")
      expect(real_source.namespace_remapping.size).to eq(1)
      expect(real_source.namespaces).to eq(["http://new.example.com/"])
      expect(real_source.schema_files).to eq(["core/schema.xsd"])
    end

    it "applies schema filtering correctly" do
      expect(real_source.include_schema?("schema.tmp.xsd")).to be false
      expect(real_source.include_schema?("core/main.xsd")).to be true
      expect(real_source.include_schema?("other/schema.xsd")).to be false
    end
  end
end
