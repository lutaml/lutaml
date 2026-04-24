# frozen_string_literal: true

require "spec_helper"
require "zip"
require "lutaml/uml_repository/package_exporter"
require "lutaml/uml_repository/package_metadata"

RSpec.describe Lutaml::UmlRepository::PackageExporter do
  let(:repository) { create_test_repository }
  let(:output_path) { temp_lur_path(prefix: "test") }

  after do
    FileUtils.rm_f(output_path)
  end

  # Helper to get permitted classes for YAML loading
  def yaml_permitted_classes
    uml_constants = Lutaml::Uml.constants
    uml_classes = uml_constants.filter_map do |const_name|
      constant_value = Lutaml::Uml.const_get(const_name)
      constant_value if constant_value.is_a?(Class)
    end
    [Symbol, Time, Date, DateTime, uml_classes].flatten
  end

  describe "#initialize" do
    it "accepts repository" do
      exporter = described_class.new(repository)
      expect(exporter).to be_a(described_class)
    end

    it "accepts PackageMetadata object" do
      metadata = Lutaml::UmlRepository::PackageMetadata.new(
        name: "Test Model",
        version: "1.0",
      )
      exporter = described_class.new(repository, metadata: metadata)
      expect(exporter.metadata).to eq(metadata)
    end

    it "accepts metadata as hash" do
      exporter = described_class.new(repository,
                                     metadata: { name: "Test", version: "1.0" })
      expect(exporter.metadata).to be_a(Lutaml::UmlRepository::PackageMetadata)
      expect(exporter.metadata.name).to eq("Test")
    end

    it "accepts old-style name/version options (backward compatible)" do
      exporter = described_class.new(repository,
                                     name: "Legacy Model",
                                     version: "2.0")
      expect(exporter.metadata.name).to eq("Legacy Model")
      expect(exporter.metadata.version).to eq("2.0")
    end

    it "defaults to UML Model v1.0" do
      exporter = described_class.new(repository)
      expect(exporter.metadata.name).to eq("UML Model")
      expect(exporter.metadata.version).to eq("1.0")
    end

    it "sets serialization_format from options" do
      exporter = described_class.new(repository, serialization_format: :yaml)
      expect(exporter.metadata.serialization_format).to eq("yaml")
    end
  end

  describe "#export" do
    it "creates ZIP file" do
      exporter = described_class.new(repository)
      exporter.export(output_path)
      expect(File.exist?(output_path)).to be true
    end

    it "creates valid ZIP file" do
      exporter = described_class.new(repository)
      exporter.export(output_path)

      expect { Zip::File.open(output_path) {} }.not_to raise_error
    end

    it "includes metadata.yaml" do
      exporter = described_class.new(repository,
                                     name: "Test Model",
                                     version: "1.2.3")
      exporter.export(output_path)

      Zip::File.open(output_path) do |zip_file|
        metadata_entry = zip_file.find_entry("metadata.yaml")
        expect(metadata_entry).not_to be_nil

        metadata = YAML.safe_load(
          metadata_entry.get_input_stream.read,
          permitted_classes: yaml_permitted_classes,
          aliases: true,
        )
        expect(metadata["name"]).to eq("Test Model")
        expect(metadata["version"]).to eq("1.2.3")
        expect(metadata).to have_key("created_at")
        expect(metadata).to have_key("created_by")
        expect(metadata).to have_key("lutaml_version")
      end
    end

    it "includes PackageMetadata fields in metadata.yaml" do
      metadata = Lutaml::UmlRepository::PackageMetadata.new(
        name: "Urban Model",
        version: "2.0",
        publisher: "City Planning",
        license: "MIT",
        description: "Urban planning model",
      )
      exporter = described_class.new(repository, metadata: metadata)
      exporter.export(output_path)

      Zip::File.open(output_path) do |zip_file|
        metadata_entry = zip_file.find_entry("metadata.yaml")
        loaded_metadata = YAML.safe_load(
          metadata_entry.get_input_stream.read,
          permitted_classes: yaml_permitted_classes,
          aliases: true,
        )

        expect(loaded_metadata["name"]).to eq("Urban Model")
        expect(loaded_metadata["version"]).to eq("2.0")
        expect(loaded_metadata["publisher"]).to eq("City Planning")
        expect(loaded_metadata["license"]).to eq("MIT")
        expect(loaded_metadata["description"]).to eq("Urban planning model")
      end
    end

    it "includes serialized repository with marshal format" do
      exporter = described_class.new(repository)
      exporter.export(output_path)

      Zip::File.open(output_path) do |zip_file|
        doc_entry = zip_file.find_entry("repository.marshal")
        expect(doc_entry).not_to be_nil

        serialized = doc_entry.get_input_stream.read
        expect { Marshal.load(serialized) }.not_to raise_error
      end
    end

    it "includes serialized repository with yaml format" do
      exporter = described_class.new(repository, serialization_format: :yaml)
      exporter.export(output_path)

      Zip::File.open(output_path) do |zip_file|
        doc_entry = zip_file.find_entry("repository.yaml")
        expect(doc_entry).not_to be_nil

        yaml_content = doc_entry.get_input_stream.read
        expect do
          YAML.safe_load(yaml_content,
                         permitted_classes: yaml_permitted_classes)
        end
          .not_to raise_error
      end
    end

    it "includes indexes" do
      exporter = described_class.new(repository)
      exporter.export(output_path)

      Zip::File.open(output_path) do |zip_file|
        indexes_entry = zip_file.find_entry("indexes/all.marshal")
        expect(indexes_entry).not_to be_nil

        serialized = indexes_entry.get_input_stream.read
        expect { Marshal.load(serialized) }.not_to raise_error
      end
    end

    it "includes index_tree.yaml" do
      exporter = described_class.new(repository)
      exporter.export(output_path)

      Zip::File.open(output_path) do |zip_file|
        tree_entry = zip_file.find_entry("index_tree.yaml")
        expect(tree_entry).not_to be_nil

        tree = YAML.safe_load(
          tree_entry.get_input_stream.read,
          permitted_classes: yaml_permitted_classes,
          aliases: true,
        )
        expect(tree).to have_key("format")
        expect(tree).to have_key("packages")
        expect(tree).to have_key("classes")
      end
    end

    it "includes statistics.yaml" do
      exporter = described_class.new(repository)
      exporter.export(output_path)

      Zip::File.open(output_path) do |zip_file|
        stats_entry = zip_file.find_entry("statistics.yaml")
        expect(stats_entry).not_to be_nil

        stats = YAML.safe_load(
          stats_entry.get_input_stream.read,
          permitted_classes: yaml_permitted_classes,
          aliases: true,
        )
        # Statistics use symbol keys
        expect(stats).to have_key(:total_packages)
        expect(stats).to have_key(:total_classes)
      end
    end

    it "raises error for invalid serialization format" do
      expect do
        described_class.new(repository, serialization_format: :invalid)
          .export(output_path)
      end.to raise_error(ArgumentError, /Invalid serialization format/)
    end

    it "raises error if output directory does not exist" do
      exporter = described_class.new(repository)
      expect { exporter.export("/nonexistent/path/test.lur") }
        .to raise_error(Errno::ENOENT)
    end

    it "overwrites existing file" do
      exporter = described_class.new(repository)
      exporter.export(output_path)

      File.size(output_path)
      exporter.export(output_path)

      expect(File.exist?(output_path)).to be true
      # File might be same size or different, just verify it exists
      expect(File.size(output_path)).to be > 0
    end
  end

  describe "backward compatibility" do
    it "works with old-style options" do
      exporter = described_class.new(repository,
                                     name: "Legacy",
                                     version: "1.0",
                                     serialization_format: :yaml)
      exporter.export(output_path)

      Zip::File.open(output_path) do |zip_file|
        # Check metadata
        metadata_entry = zip_file.find_entry("metadata.yaml")
        metadata = YAML.safe_load(
          metadata_entry.get_input_stream.read,
          permitted_classes: yaml_permitted_classes,
          aliases: true,
        )
        expect(metadata["name"]).to eq("Legacy")
        expect(metadata["version"]).to eq("1.0")

        # Check document format
        doc_entry = zip_file.find_entry("repository.yaml")
        expect(doc_entry).not_to be_nil
      end
    end

    it "works with old-style options (marshal format)" do
      exporter = described_class.new(repository,
                                     name: "Legacy",
                                     version: "1.0",
                                     serialization_format: :marshal)
      exporter.export(output_path)

      Zip::File.open(output_path) do |zip_file|
        # Check metadata
        metadata_entry = zip_file.find_entry("metadata.yaml")
        metadata = YAML.safe_load(
          metadata_entry.get_input_stream.read,
          permitted_classes: yaml_permitted_classes,
          aliases: true,
        )
        expect(metadata["name"]).to eq("Legacy")
        expect(metadata["version"]).to eq("1.0")

        # Check document format
        doc_entry = zip_file.find_entry("repository.marshal")
        expect(doc_entry).not_to be_nil
      end
    end

    it "metadata hash takes precedence over old-style options" do
      exporter = described_class.new(repository,
                                     name: "Old",
                                     version: "1.0",
                                     metadata: { name: "New", version: "2.0" })

      expect(exporter.metadata.name).to eq("New")
      expect(exporter.metadata.version).to eq("2.0")
    end
  end

  describe "metadata priority" do
    it "PackageMetadata object has highest priority" do
      metadata_obj = Lutaml::UmlRepository::PackageMetadata.new(
        name: "Object",
        version: "3.0",
      )
      exporter = described_class.new(repository,
                                     metadata: metadata_obj,
                                     name: "Hash",
                                     version: "2.0")

      expect(exporter.metadata.name).to eq("Object")
      expect(exporter.metadata.version).to eq("3.0")
    end

    it "metadata hash has second priority" do
      exporter = described_class.new(repository,
                                     metadata: { name: "Hash", version: "2.0" },
                                     name: "Options",
                                     version: "1.0")

      expect(exporter.metadata.name).to eq("Hash")
      expect(exporter.metadata.version).to eq("2.0")
    end

    it "old-style options have lowest priority" do
      exporter = described_class.new(repository,
                                     name: "Options",
                                     version: "1.0")

      expect(exporter.metadata.name).to eq("Options")
      expect(exporter.metadata.version).to eq("1.0")
    end
  end
end
