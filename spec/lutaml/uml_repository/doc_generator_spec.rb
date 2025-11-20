# frozen_string_literal: true

require "spec_helper"
require_relative "../../../lib/lutaml/uml_repository/doc_generator"
require "tempfile"
require "fileutils"

RSpec.describe Lutaml::UmlRepository::DocGenerator do
  let(:repository) { instance_double("Lutaml::UmlRepository::UmlRepository") }
  let(:generator) { described_class.new(repository) }
  let(:temp_dir) { Dir.mktmpdir }

  let(:indexes) do
    {
      classes: {},
      class_to_qname: {},
      package_to_path: {},
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
    allow(repository).to receive(:indexes).and_return(indexes)
    allow(repository).to receive(:statistics).and_return(statistics)
    allow(repository).to receive(:package_tree).and_return(tree)
    allow(repository).to receive(:list_packages).and_return([])
    allow(repository).to receive(:all_diagrams).and_return([])
  end

  after do
    FileUtils.rm_rf(temp_dir)
  end

  describe "#generate" do
    it "creates the directory structure" do
      generator.generate(temp_dir)

      expect(File.directory?(temp_dir)).to be true
      expect(File.directory?(File.join(temp_dir, "packages"))).to be true
      expect(File.directory?(File.join(temp_dir, "classes"))).to be true
      expect(File.directory?(File.join(temp_dir, "assets"))).to be true
    end

    it "generates index page" do
      generator.generate(temp_dir)

      index_path = File.join(temp_dir, "index.html")
      expect(File.exist?(index_path)).to be true

      content = File.read(index_path)
      expect(content).to include("<title>UML Model Documentation</title>")
      expect(content).to include("Overview")
    end

    it "generates search index" do
      generator.generate(temp_dir)

      search_index = File.join(temp_dir, "assets", "search-index.json")
      expect(File.exist?(search_index)).to be true
    end

    it "generates static assets" do
      generator.generate(temp_dir)

      styles = File.join(temp_dir, "assets", "styles.css")
      script = File.join(temp_dir, "assets", "search.js")

      expect(File.exist?(styles)).to be true
      expect(File.exist?(script)).to be true
    end

    it "uses custom title when provided" do
      generator.generate(temp_dir, title: "My Custom Documentation")

      index_path = File.join(temp_dir, "index.html")
      content = File.read(index_path)
      expect(content).to include("<title>My Custom Documentation</title>")
    end
  end
end
