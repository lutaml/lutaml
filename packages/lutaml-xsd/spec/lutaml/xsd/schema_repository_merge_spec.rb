# frozen_string_literal: true

require "spec_helper"

RSpec.describe Lutaml::Xsd::SchemaRepository, "package merging" do
  let(:temp_dir) do
    dir = File.join(Dir.pwd, "tmp_test_#{SecureRandom.hex(8)}")
    FileUtils.mkdir_p(dir)
    dir
  end

  after { FileUtils.rm_rf(temp_dir) }

  # Helper to create minimal test package
  def create_test_package(path, namespace, schema_content)
    require "zip"

    # Remove file if it exists
    FileUtils.rm_f(path)

    Zip::File.open(path, create: true) do |zipfile|
      # Add schema file
      schema_filename = "test.xsd"
      zipfile.get_output_stream("schemas/#{schema_filename}") do |f|
        f.write(schema_content)
      end

      # Add namespace mappings (required for metadata)
      ns_mappings = [{ "prefix" => "test", "uri" => namespace }]

      # Add metadata with all required fields
      metadata = {
        "format_version" => "1.0",
        "created_at" => Time.now.iso8601,
        "lutaml_xsd_version" => Lutaml::Xsd::VERSION,
        "files" => ["schemas/#{schema_filename}"],
        "namespace_mappings" => ns_mappings,
        "schema_location_mappings" => [],
      }
      zipfile.get_output_stream("metadata.yaml") do |f|
        f.write(YAML.dump(metadata))
      end

      # Add serialized schema (minimal marshal data)
      schema = Lutaml::Xsd::Schema.new(target_namespace: namespace)
      zipfile.get_output_stream("schemas_data/#{schema_filename}.marshal") do |f|
        f.write(Marshal.dump(schema))
      end
    end
  end

  # Helper to create YAML config
  def create_yaml_config(path, config_hash)
    File.write(path, YAML.dump(config_hash))
  end

  describe "#normalize_base_packages_to_configs" do
    context "with hash array" do
      it "converts hashes to BasePackageConfig objects" do
        repo = described_class.new
        repo.base_packages = [
          { "package" => "pkg1.lxr", "priority" => 10 },
          { "package" => "pkg2.lxr", "conflict_resolution" => "keep" },
        ]

        configs = repo.normalize_base_packages_to_configs

        expect(configs[0].package).to eq("pkg1.lxr")
        expect(configs[0].priority).to eq(10)
        expect(configs[1].conflict_resolution).to eq("keep")
      end
    end

    context "with BasePackageConfig objects" do
      it "passes through unchanged" do
        config = Lutaml::Xsd::BasePackageConfig.new(package: "pkg1.lxr")
        repo = described_class.new
        repo.base_packages = [config]

        configs = repo.normalize_base_packages_to_configs

        expect(configs[0]).to be_a(Lutaml::Xsd::BasePackageConfig)
        expect(configs[0].package).to eq("pkg1.lxr")
      end
    end
  end

  describe "#supports_conflict_detection?" do
    it "returns true for hash array" do
      repo = described_class.new
      repo.base_packages = [{ "package" => "pkg1.lxr" }]
      expect(repo.send(:supports_conflict_detection?)).to be true
    end

    it "returns true for BasePackageConfig array" do
      config = Lutaml::Xsd::BasePackageConfig.new(package: "pkg1.lxr")
      repo = described_class.new
      repo.base_packages = [config]
      expect(repo.send(:supports_conflict_detection?)).to be true
    end

    it "returns false for empty array" do
      repo = described_class.new
      repo.base_packages = []
      expect(repo.send(:supports_conflict_detection?)).to be false
    end
  end

  describe "YAML configuration loading with conflict detection" do
    let(:pkg1_path) { File.join(temp_dir, "pkg1.lxr") }
    let(:pkg2_path) { File.join(temp_dir, "pkg2.lxr") }
    let(:config_path) { File.join(temp_dir, "config.yml") }

    before do
      create_test_package(
        pkg1_path,
        "http://example.com/ns1",
        '<xs:schema xmlns:xs="http://www.w3.org/2001/XMLSchema" targetNamespace="http://example.com/ns1"/>',
      )
      create_test_package(
        pkg2_path,
        "http://example.com/ns2",
        '<xs:schema xmlns:xs="http://www.w3.org/2001/XMLSchema" targetNamespace="http://example.com/ns2"/>',
      )
    end

    it "loads configuration with conflict resolution settings" do
      create_yaml_config(config_path, {
                           "base_packages" => [
                             { "package" => pkg1_path, "priority" => 0,
                               "conflict_resolution" => "keep" },
                             { "package" => pkg2_path, "priority" => 10,
                               "conflict_resolution" => "override" },
                           ],
                         })

      repo = described_class.from_yaml_file(config_path)

      expect(repo.base_packages).to be_an(Array)
      expect(repo.base_packages.size).to eq(2)

      # The YAML loader should preserve the structure
      expect { repo.parse }.not_to raise_error
    end
  end

  describe "conflict detection and resolution" do
    let(:pkg1_path) { File.join(temp_dir, "pkg1.lxr") }
    let(:pkg2_path) { File.join(temp_dir, "pkg2.lxr") }

    before do
      # Create two packages with the SAME namespace (conflict!)
      create_test_package(
        pkg1_path,
        "http://example.com/shared",
        '<xs:schema xmlns:xs="http://www.w3.org/2001/XMLSchema" targetNamespace="http://example.com/shared"/>',
      )
      create_test_package(
        pkg2_path,
        "http://example.com/shared", # Same namespace = conflict
        '<xs:schema xmlns:xs="http://www.w3.org/2001/XMLSchema" targetNamespace="http://example.com/shared"/>',
      )
    end

    it "detects conflicts with 'error' strategy and raises" do
      repo = described_class.new
      repo.base_packages = [
        { "package" => pkg1_path, "conflict_resolution" => "error" },
        { "package" => pkg2_path, "conflict_resolution" => "error" },
      ]

      expect { repo.parse }.to raise_error(Lutaml::Xsd::PackageMergeError)
    end

    it "allows conflicts with 'keep' strategy" do
      repo = described_class.new
      repo.base_packages = [
        { "package" => pkg1_path, "priority" => 0,
          "conflict_resolution" => "keep" },
        { "package" => pkg2_path, "priority" => 10,
          "conflict_resolution" => "keep" },
      ]

      expect { repo.parse }.not_to raise_error
    end

    it "allows conflicts with 'override' strategy" do
      repo = described_class.new
      repo.base_packages = [
        { "package" => pkg1_path, "priority" => 0,
          "conflict_resolution" => "override" },
        { "package" => pkg2_path, "priority" => 10,
          "conflict_resolution" => "override" },
      ]

      expect { repo.parse }.not_to raise_error
    end
  end

  describe "validation of configuration" do
    let(:pkg_path) { File.join(temp_dir, "test.lxr") }

    before do
      create_test_package(
        pkg_path,
        "http://example.com/ns1",
        '<xs:schema xmlns:xs="http://www.w3.org/2001/XMLSchema" targetNamespace="http://example.com/ns1"/>',
      )
    end

    it "raises ValidationFailedError for invalid conflict_resolution" do
      repo = described_class.new
      repo.base_packages = [
        { "package" => pkg_path, "conflict_resolution" => "invalid" },
      ]

      expect { repo.parse }.to raise_error(Lutaml::Xsd::ValidationFailedError)
    end

    it "raises ValidationFailedError for negative priority" do
      repo = described_class.new
      repo.base_packages = [
        { "package" => pkg_path, "priority" => -1 },
      ]

      expect { repo.parse }.to raise_error(Lutaml::Xsd::ValidationFailedError)
    end

    it "raises ConfigurationError for missing package file" do
      repo = described_class.new
      repo.base_packages = [
        { "package" => "/nonexistent/package.lxr" },
      ]

      expect do
        repo.parse
      end.to raise_error(Lutaml::Xsd::ConfigurationError, /not found/)
    end
  end

  describe "schema filtering" do
    let(:pkg_path) { File.join(temp_dir, "test.lxr") }

    before do
      create_test_package(
        pkg_path,
        "http://example.com/ns1",
        '<xs:schema xmlns:xs="http://www.w3.org/2001/XMLSchema" targetNamespace="http://example.com/ns1"/>',
      )
    end

    it "supports exclude_schemas filters" do
      repo = described_class.new
      repo.base_packages = [
        {
          "package" => pkg_path,
          "exclude_schemas" => ["**/test.xsd"],
        },
      ]

      expect { repo.parse }.not_to raise_error
    end

    it "supports include_only_schemas filters" do
      repo = described_class.new
      repo.base_packages = [
        {
          "package" => pkg_path,
          "include_only_schemas" => ["**/other.xsd"], # Won't match anything
        },
      ]

      expect { repo.parse }.not_to raise_error
    end
  end
end
