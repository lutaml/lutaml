# frozen_string_literal: true

require "spec_helper"
require_relative "../../../../lib/lutaml/uml_repository/exporters/csv_exporter"
require "csv"
require "tempfile"

RSpec.describe Lutaml::UmlRepository::Exporters::CsvExporter do
  let(:repository) { instance_double("Lutaml::UmlRepository::UmlRepository") }
  let(:exporter) { described_class.new(repository) }
  let(:temp_file) { Tempfile.new(["test", ".csv"]) }
  let(:output_path) { temp_file.path }

  let(:mock_class) do
    instance_double(
      "Lutaml::Uml::Class",
      xmi_id: "class1",
      name: "Building",
      stereotypes: ["featureType"],
      attributes: [
        instance_double(
          "Lutaml::Uml::Attribute",
          name: "address",
          type: "String",
          visibility: "public",
          cardinality: nil,
        ),
      ],
    )
  end

  let(:indexes) do
    {
      classes: { "class1" => mock_class },
      class_to_qname: { "class1" => "ModelRoot::i-UR::urf::Building" },
    }
  end

  before do
    allow(repository).to receive(:indexes).and_return(indexes)
  end

  after do
    temp_file.close
    temp_file.unlink
  end

  describe "#export" do
    context "with basic options" do
      it "exports classes to CSV" do
        allow(repository).to receive(:associations_of).and_return([])

        exporter.export(output_path)

        csv = CSV.read(output_path, headers: true)
        expect(csv.length).to eq(1)
        expect(csv[0]["Qualified Name"]).to eq("ModelRoot::i-UR::urf::Building")
        expect(csv[0]["Name"]).to eq("Building")
        expect(csv[0]["Stereotype"]).to eq("featureType")
        expect(csv[0]["Attributes Count"]).to eq("1")
      end
    end

    context "with include_attributes option" do
      it "includes attributes as separate rows" do
        allow(repository).to receive(:associations_of).and_return([])

        exporter.export(output_path, include_attributes: true)

        csv = CSV.read(output_path, headers: true)
        expect(csv.length).to eq(1)
        expect(csv[0]["Attribute Name"]).to eq("address")
        expect(csv[0]["Attribute Type"]).to eq("String")
      end
    end

    context "with package filter" do
      it "filters classes by package" do
        allow(repository).to receive(:classes_in_package)
          .with("ModelRoot::i-UR::urf", recursive: false)
          .and_return([mock_class])
        allow(repository).to receive(:associations_of).and_return([])

        exporter.export(output_path, package: "ModelRoot::i-UR::urf")

        csv = CSV.read(output_path, headers: true)
        expect(csv.length).to eq(1)
      end
    end

    context "with stereotype filter" do
      it "filters classes by stereotype" do
        allow(repository).to receive(:associations_of).and_return([])

        exporter.export(output_path, stereotype: "featureType")

        csv = CSV.read(output_path, headers: true)
        expect(csv.length).to eq(1)
        expect(csv[0]["Stereotype"]).to eq("featureType")
      end
    end
  end
end
