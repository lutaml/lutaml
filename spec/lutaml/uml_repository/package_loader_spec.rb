# frozen_string_literal: true

require "spec_helper"
require "zip"

RSpec.describe Lutaml::UmlRepository::PackageLoader do
  let(:repository) { create_test_repository }
  let(:lur_path) { "spec/tmp/test.lur" }

  before do
    FileUtils.mkdir_p("spec/tmp")
    # Create a test LUR file
    exporter = Lutaml::UmlRepository::PackageExporter.new(repository)
    exporter.export(lur_path)
  end

  after do
    FileUtils.rm_f(lur_path)
  end

  describe ".load" do
    it "loads repository from package" do
      loaded_repo = described_class.load(lur_path)
      expect(loaded_repo).to be_a(Lutaml::UmlRepository::Repository)
    end

    it "deserializes document" do
      loaded_repo = described_class.load(lur_path)
      expect(loaded_repo.document).to be_a(Lutaml::Uml::Document)
    end

    it "loads indexes" do
      loaded_repo = described_class.load(lur_path)
      expect(loaded_repo.indexes).to be_a(Hash)
      expect(loaded_repo.indexes.keys).to include(
        :package_paths,
        :qualified_names,
        :stereotypes,
        :inheritance_graph,
        :diagram_index,
      )
    end

    it "creates functional repository" do
      loaded_repo = described_class.load(lur_path)

      # Test that queries work
      packages = loaded_repo.list_packages(loaded_repo.document.name)
      expect(packages).to be_an(Array)
    end

    it "preserves document structure" do
      original_doc = repository.document
      loaded_repo = described_class.load(lur_path)
      loaded_doc = loaded_repo.document

      expect(loaded_doc.name).to eq(original_doc.name)
      expect(loaded_doc.packages.length).to eq(original_doc.packages.length)
    end

    it "preserves indexes" do
      original_indexes = repository.indexes
      loaded_repo = described_class.load(lur_path)
      loaded_indexes = loaded_repo.indexes

      expect(loaded_indexes[:package_paths].keys.map(&:to_s).sort)
        .to eq(original_indexes[:package_paths].keys.map(&:to_s).sort)
    end

    it "handles missing files" do
      expect { described_class.load("nonexistent.lur") }
        .to raise_error(Errno::ENOENT)
    end

    it "handles corrupted files" do
      # Create a corrupted file
      File.write(lur_path, "corrupted data")

      expect { described_class.load(lur_path) }
        .to raise_error(Zip::Error)
    end
  end

  describe "round-trip test" do
    it "preserves data through export and load cycle" do
      # Export
      exporter = Lutaml::UmlRepository::PackageExporter.new(repository)
      exporter.export(lur_path)

      # Load
      loaded_repo = described_class.load(lur_path)

      # Compare
      expect(loaded_repo.document.name).to eq(repository.document.name)
      expect(loaded_repo.statistics[:total_packages])
        .to eq(repository.statistics[:total_packages])
      expect(loaded_repo.statistics[:total_classes])
        .to eq(repository.statistics[:total_classes])
    end

    it "maintains query functionality" do
      loaded_repo = described_class.load(lur_path)

      # Test various queries
      doc_name = loaded_repo.document.name
      packages = loaded_repo.list_packages(doc_name)
      expect(packages).to be_an(Array)

      all_classes = loaded_repo.search_classes("*")
      expect(all_classes).to be_an(Array)
    end
  end

  describe "with YAML format" do
    before do
      FileUtils.rm_f(lur_path)
      exporter = Lutaml::UmlRepository::PackageExporter.new(
        repository,
        format: :yaml,
      )
      exporter.export(lur_path)
    end

    it "loads from YAML format" do
      loaded_repo = described_class.load(lur_path)
      expect(loaded_repo).to be_a(Lutaml::UmlRepository::Repository)
    end

    it "deserializes YAML document correctly" do
      loaded_repo = described_class.load(lur_path)
      expect(loaded_repo.document).to be_a(Lutaml::Uml::Document)
    end
  end
end
