# frozen_string_literal: true

require "spec_helper"
require_relative "../../../../lib/lutaml/uml_repository/exporters/json_exporter"
require "json"
require "tempfile"

RSpec.describe Lutaml::UmlRepository::Exporters::JsonExporter do
  let(:repository) { instance_double(Lutaml::UmlRepository::Repository) }
  let(:exporter) { described_class.new(repository) }
  let(:temp_file) { Tempfile.new(["test", ".json"]) }
  let(:output_path) { temp_file.path }

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

  let(:indexes) do
    {
      classes: { "class1" => mock_class },
      class_to_qname: { "class1" => "ModelRoot::i-UR::urf::Building" },
      associations: {},
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

  before do
    allow(repository).to receive_messages(indexes: indexes,
                                          statistics: statistics, list_packages: [], all_diagrams: [], supertype_of: nil)
  end

  after do
    temp_file.close
    temp_file.unlink
  end

  describe "#export" do
    it "exports repository to JSON", :aggregate_failures do
      exporter.export(output_path)

      data = JSON.parse(File.read(output_path))
      expect(data).to have_key("metadata")
      expect(data).to have_key("packages")
      expect(data).to have_key("classes")
      expect(data).to have_key("associations")
    end

    it "includes metadata", :aggregate_failures do
      exporter.export(output_path)

      data = JSON.parse(File.read(output_path))
      expect(data["metadata"]["total_classes"]).to eq(10)
      expect(data["metadata"]["total_packages"]).to eq(3)
    end

    it "exports classes with details", :aggregate_failures do
      exporter.export(output_path)

      data = JSON.parse(File.read(output_path))
      expect(data["classes"]).to be_an(Array)
      expect(data["classes"].first["name"]).to eq("Building")
      expect(data["classes"].first["qualified_name"])
        .to eq("ModelRoot::i-UR::urf::Building")
    end

    it "supports pretty printing", :aggregate_failures do
      exporter.export(output_path, pretty: true)

      content = File.read(output_path)
      expect(content).to include("\n")
      expect(content.lines.count).to be > 10
    end
  end
end
