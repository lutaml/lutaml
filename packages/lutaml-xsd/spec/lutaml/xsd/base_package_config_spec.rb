# frozen_string_literal: true

require "spec_helper"
require "lutaml/xsd/base_package_config"

RSpec.describe Lutaml::Xsd::BasePackageConfig do
  describe "#validate" do
    context "with valid configuration" do
      it "returns success result" do
        config = described_class.new(
          package: "path/to/package.lxr",
          priority: 0,
          conflict_resolution: "error",
        )

        result = config.validate

        expect(result).to be_valid
        expect(result.errors).to be_empty
      end
    end

    context "when package is missing" do
      it "returns failure result with error" do
        config = described_class.new(
          package: nil,
          priority: 0,
          conflict_resolution: "error",
        )

        result = config.validate

        expect(result).to be_invalid
        expect(result.error_count).to eq(1)
        expect(result.errors.first.field).to eq("package")
        expect(result.errors.first.message).to eq("Package path is required")
        expect(result.errors.first.constraint).to eq("presence")
      end
    end

    context "when package is empty" do
      it "returns failure result with error" do
        config = described_class.new(
          package: "",
          priority: 0,
          conflict_resolution: "error",
        )

        result = config.validate

        expect(result).to be_invalid
        expect(result.errors_for(:package).size).to eq(1)
      end
    end

    context "when conflict_resolution is invalid" do
      it "returns failure result with error" do
        config = described_class.new(
          package: "path/to/package.lxr",
          priority: 0,
          conflict_resolution: "invalid_strategy",
        )

        result = config.validate

        expect(result).to be_invalid
        expect(result.error_count).to eq(1)
        expect(result.errors.first.field).to eq("conflict_resolution")
        expect(result.errors.first.message).to eq(
          "Invalid conflict resolution strategy",
        )
        expect(result.errors.first.value).to eq("invalid_strategy")
        expect(result.errors.first.constraint).to include("keep", "override",
                                                          "error")
      end
    end

    context "with valid conflict_resolution strategies" do
      %w[keep override error].each do |strategy|
        it "accepts '#{strategy}' strategy" do
          config = described_class.new(
            package: "path/to/package.lxr",
            conflict_resolution: strategy,
          )

          expect(config.validate).to be_valid
        end
      end
    end

    context "when priority is negative" do
      it "returns failure result with error" do
        config = described_class.new(
          package: "path/to/package.lxr",
          priority: -1,
          conflict_resolution: "error",
        )

        result = config.validate

        expect(result).to be_invalid
        expect(result.error_count).to eq(1)
        expect(result.errors.first.field).to eq("priority")
        expect(result.errors.first.message).to eq(
          "Priority must be non-negative",
        )
        expect(result.errors.first.value).to eq("-1")
        expect(result.errors.first.constraint).to eq(">= 0")
      end
    end

    context "with invalid nested namespace_remapping" do
      it "returns failure result with nested errors" do
        remap = Lutaml::Xsd::NamespaceUriRemapping.new(
          from_uri: nil,
          to_uri: "http://example.com/new",
        )

        config = described_class.new(
          package: "path/to/package.lxr",
          namespace_remapping: [remap],
        )

        result = config.validate

        expect(result).to be_invalid
        expect(result.error_count).to eq(1)
        expect(result.errors.first.field).to eq("namespace_remapping[0].from_uri")
        expect(result.errors.first.message).to eq("Source URI is required")
      end
    end

    context "with multiple validation errors" do
      it "returns all errors" do
        config = described_class.new(
          package: nil,
          priority: -1,
          conflict_resolution: "wrong",
        )

        result = config.validate

        expect(result).to be_invalid
        expect(result.error_count).to eq(3)
        expect(result.errors_for(:package).size).to eq(1)
        expect(result.errors_for(:priority).size).to eq(1)
        expect(result.errors_for(:conflict_resolution).size).to eq(1)
      end
    end
  end

  describe "#valid?" do
    it "returns true for valid config" do
      config = described_class.new(
        package: "path/to/package.lxr",
      )

      expect(config).to be_valid
    end

    it "returns false for invalid config" do
      config = described_class.new(package: nil)
      expect(config).not_to be_valid
    end
  end

  describe "#validate!" do
    context "when valid" do
      it "does not raise error" do
        config = described_class.new(package: "path/to/package.lxr")
        expect { config.validate! }.not_to raise_error
      end
    end

    context "when invalid" do
      it "raises ValidationFailedError" do
        config = described_class.new(package: nil)

        expect { config.validate! }.to raise_error(
          Lutaml::Xsd::ValidationFailedError,
        )
      end
    end
  end

  describe "#include_schema?" do
    context "with exclude_schemas" do
      let(:config) do
        described_class.new(
          package: "path/to/package.lxr",
          exclude_schemas: ["test/**/*.xsd", "*.tmp.xsd"],
        )
      end

      it "excludes matching schemas" do
        expect(config.include_schema?("test/schema.xsd")).to be false
        expect(config.include_schema?("test/sub/schema.xsd")).to be false
        expect(config.include_schema?("schema.tmp.xsd")).to be false
      end

      it "includes non-matching schemas" do
        expect(config.include_schema?("src/schema.xsd")).to be true
        expect(config.include_schema?("schema.xsd")).to be true
      end
    end

    context "with include_only_schemas" do
      let(:config) do
        described_class.new(
          package: "path/to/package.lxr",
          include_only_schemas: ["src/**/*.xsd", "core.xsd"],
        )
      end

      it "includes only matching schemas" do
        expect(config.include_schema?("src/schema.xsd")).to be true
        expect(config.include_schema?("src/sub/schema.xsd")).to be true
        expect(config.include_schema?("core.xsd")).to be true
      end

      it "excludes non-matching schemas" do
        expect(config.include_schema?("test/schema.xsd")).to be false
        expect(config.include_schema?("other.xsd")).to be false
      end
    end

    context "with both exclude and include filters" do
      let(:config) do
        described_class.new(
          package: "path/to/package.lxr",
          exclude_schemas: ["**/*test*.xsd"],
          include_only_schemas: ["src/**/*.xsd"],
        )
      end

      it "prioritizes exclude over include" do
        expect(config.include_schema?("src/schema_test.xsd")).to be false
        expect(config.include_schema?("src/schema.xsd")).to be true
        expect(config.include_schema?("other/schema.xsd")).to be false
      end
    end

    context "without any filters" do
      let(:config) do
        described_class.new(package: "path/to/package.lxr")
      end

      it "includes all schemas" do
        expect(config.include_schema?("any/path/schema.xsd")).to be true
        expect(config.include_schema?("test/schema.xsd")).to be true
      end
    end
  end

  describe "serialization" do
    let(:config) do
      described_class.new(
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
        include_only_schemas: ["src/**/*.xsd"],
      )
    end

    describe "#to_hash" do
      it "converts to hash with all fields" do
        hash = config.to_hash

        expect(hash["package"]).to eq("path/to/package.lxr")
        expect(hash["priority"]).to eq(5)
        expect(hash["conflict_resolution"]).to eq("keep")
        expect(hash["namespace_remapping"]).to be_an(Array)
        expect(hash["exclude_schemas"]).to eq(["test/**/*.xsd"])
        expect(hash["include_only_schemas"]).to eq(["src/**/*.xsd"])
      end
    end

    describe "YAML round-trip" do
      it "serializes and deserializes correctly" do
        yaml = config.to_yaml
        loaded = described_class.from_yaml(yaml)

        expect(loaded.package).to eq(config.package)
        expect(loaded.priority).to eq(config.priority)
        expect(loaded.conflict_resolution).to eq(config.conflict_resolution)
        expect(loaded.namespace_remapping.first.from_uri).to eq(
          config.namespace_remapping.first.from_uri,
        )
        expect(loaded.exclude_schemas).to eq(config.exclude_schemas)
        expect(loaded.include_only_schemas).to eq(config.include_only_schemas)
      end
    end

    describe "JSON round-trip" do
      it "serializes and deserializes correctly" do
        json = config.to_json
        loaded = described_class.from_json(json)

        expect(loaded.package).to eq(config.package)
        expect(loaded.priority).to eq(config.priority)
        expect(loaded.conflict_resolution).to eq(config.conflict_resolution)
      end
    end

    context "with minimal configuration" do
      let(:minimal_config) do
        described_class.new(package: "path/to/package.lxr")
      end

      it "uses default values" do
        expect(minimal_config.priority).to eq(0)
        expect(minimal_config.conflict_resolution).to eq("error")
      end

      it "round-trips with defaults" do
        yaml = minimal_config.to_yaml
        loaded = described_class.from_yaml(yaml)

        expect(loaded.package).to eq("path/to/package.lxr")
        expect(loaded.priority).to eq(0)
        expect(loaded.conflict_resolution).to eq("error")
      end
    end
  end
end
