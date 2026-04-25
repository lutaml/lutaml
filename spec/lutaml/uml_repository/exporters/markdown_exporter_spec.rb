# frozen_string_literal: true

require "spec_helper"
require_relative "../../../../lib/lutaml/uml_repository/exporters/" \
                 "markdown_exporter"
require "tempfile"
require "fileutils"

RSpec.describe Lutaml::UmlRepository::Exporters::MarkdownExporter do
  let(:repository) { instance_double(Lutaml::UmlRepository::Repository) }
  let(:exporter) { described_class.new(repository) }
  let(:temp_dir) { Dir.mktmpdir }

  let(:mock_class) do
    instance_double(
      Lutaml::Uml::Class,
      xmi_id: "class1",
      name: "Building",
      class: Lutaml::Uml::Class,
      stereotype: ["featureType"],
      attributes: [],
      operations: nil,
      definition: "A building structure",
    )
  end

  let(:mock_package) do
    instance_double(
      Lutaml::Uml::Package,
      xmi_id: "pkg1",
      name: "urf",
      definition: "Urban features package",
      packages: [],
      classes: [],
    )
  end

  let(:indexes) do
    {
      classes: { "class1" => mock_class },
      class_to_qname: { "class1" => "ModelRoot::i-UR::urf::Building" },
      package_to_path: { "pkg1" => "ModelRoot::i-UR::urf" },
    }
  end

  let(:statistics) do
    {
      total_packages: 3,
      total_classes: 10,
      total_associations: 5,
      total_diagrams: 2,
    }
  end

  let(:tree) do
    {
      name: "ModelRoot",
      path: "ModelRoot",
      classes_count: 0,
      children: [],
    }
  end

  before do
    allow(repository).to receive_messages(indexes: indexes,
                                          statistics: statistics, package_tree: tree, list_packages: [mock_package], classes_in_package: [mock_class], diagrams_in_package: [], associations_of: [], supertype_of: nil, subtypes_of: [])
  end

  after do
    FileUtils.rm_rf(temp_dir)
  end

  describe "#export" do
    it "creates the directory structure", :aggregate_failures do
      exporter.export(temp_dir)

      expect(File.directory?(temp_dir)).to be true
      expect(File.directory?(File.join(temp_dir, "packages"))).to be true
      expect(File.directory?(File.join(temp_dir, "classes"))).to be true
    end

    it "generates index page", :aggregate_failures do
      exporter.export(temp_dir)

      index_path = File.join(temp_dir, "index.md")
      expect(File.exist?(index_path)).to be true

      content = File.read(index_path)
      expect(content).to include("# UML Model Documentation")
      expect(content).to include("## Statistics")
    end

    it "generates package pages" do
      exporter.export(temp_dir)

      packages_dir = File.join(temp_dir, "packages")
      expect(Dir.empty?(packages_dir)).to be false
    end

    it "generates class pages" do
      exporter.export(temp_dir)

      classes_dir = File.join(temp_dir, "classes")
      expect(Dir.empty?(classes_dir)).to be false
    end

    it "uses custom title when provided" do
      exporter.export(temp_dir, title: "My Custom Title")

      index_path = File.join(temp_dir, "index.md")
      content = File.read(index_path)
      expect(content).to include("# My Custom Title")
    end
  end
end
