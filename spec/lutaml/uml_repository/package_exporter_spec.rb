# frozen_string_literal: true

require "spec_helper"
require "zip"

RSpec.describe Lutaml::UmlRepository::PackageExporter do
  let(:repository) { create_test_repository }
  let(:output_path) { "spec/tmp/test.lur" }

  before do
    FileUtils.mkdir_p("spec/tmp")
  end

  after do
    FileUtils.rm_f(output_path)
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

    it "includes metadata" do
      exporter = described_class.new(repository)
      exporter.export(output_path)

      Zip::File.open(output_path) do |zip_file|
        metadata_entry = zip_file.find_entry("metadata.json")
        expect(metadata_entry).not_to be_nil

        metadata = JSON.parse(metadata_entry.get_input_stream.read)
        expect(metadata).to have_key("version")
        expect(metadata).to have_key("created_at")
        expect(metadata).to have_key("lutaml_version")
      end
    end

    it "includes serialized document" do
      exporter = described_class.new(repository)
      exporter.export(output_path)

      Zip::File.open(output_path) do |zip_file|
        doc_entry = zip_file.find_entry("document.marshal")
        expect(doc_entry).not_to be_nil
      end
    end

    it "includes indexes" do
      exporter = described_class.new(repository)
      exporter.export(output_path)

      Zip::File.open(output_path) do |zip_file|
        indexes_entry = zip_file.find_entry("indexes.marshal")
        expect(indexes_entry).not_to be_nil
      end
    end

    it "includes statistics" do
      exporter = described_class.new(repository)
      exporter.export(output_path)

      Zip::File.open(output_path) do |zip_file|
        stats_entry = zip_file.find_entry("statistics.json")
        expect(stats_entry).not_to be_nil

        stats = JSON.parse(stats_entry.get_input_stream.read)
        expect(stats).to have_key("total_packages")
        expect(stats).to have_key("total_classes")
      end
    end

    context "with marshal format" do
      it "serializes document as marshal" do
        exporter = described_class.new(repository, format: :marshal)
        exporter.export(output_path)

        Zip::File.open(output_path) do |zip_file|
          doc_entry = zip_file.find_entry("document.marshal")
          expect(doc_entry).not_to be_nil

          serialized = doc_entry.get_input_stream.read
          expect { Marshal.load(serialized) }.not_to raise_error
        end
      end
    end

    context "with yaml format" do
      it "serializes document as yaml" do
        exporter = described_class.new(repository, format: :yaml)
        exporter.export(output_path)

        Zip::File.open(output_path) do |zip_file|
          doc_entry = zip_file.find_entry("document.yaml")
          expect(doc_entry).not_to be_nil

          yaml_content = doc_entry.get_input_stream.read
          expect { YAML.safe_load(yaml_content, permitted_classes: [Symbol]) }
            .not_to raise_error
        end
      end
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
    end
  end

  describe "#initialize" do
    it "accepts repository" do
      exporter = described_class.new(repository)
      expect(exporter).to be_a(described_class)
    end

    it "accepts format option" do
      exporter = described_class.new(repository, format: :yaml)
      expect(exporter).to be_a(described_class)
    end

    it "defaults to marshal format" do
      exporter = described_class.new(repository)
      expect(exporter).to be_a(described_class)
    end
  end
end
