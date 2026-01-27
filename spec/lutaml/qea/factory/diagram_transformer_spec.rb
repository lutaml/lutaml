# frozen_string_literal: true

require "spec_helper"
require_relative "../../../../lib/lutaml/qea/factory/diagram_transformer"
require_relative "../../../../lib/lutaml/qea/models/ea_diagram"

RSpec.describe Lutaml::Qea::Factory::DiagramTransformer do
  let(:connection) { double("Connection") }
  let(:database) { double("Database", connection: connection) }
  let(:transformer) { described_class.new(database) }

  describe "#transform" do
    it "returns nil for nil input" do
      result = transformer.transform(nil)
      expect(result).to be_nil
    end

    it "transforms EA diagram to UML diagram" do
      ea_diagram = Lutaml::Qea::Models::EaDiagram.new(
        diagram_id: 1,
        name: "Class Diagram",
        ea_guid: "{DIAG-GUID}",
        package_id: 5,
        notes: "Main class diagram",
      )

      package_row = {
        "Package_ID" => 5,
        "Name" => "Domain",
      }

      allow(connection).to receive(:execute)
        .with(/SELECT.*t_package.*Package_ID/, 5)
        .and_return([package_row])
      allow(connection).to receive(:execute)
        .with("SELECT * FROM t_diagramobjects WHERE Diagram_ID = ?", 1)
        .and_return([])
      allow(connection).to receive(:execute)
        .with("SELECT * FROM t_diagramlinks WHERE DiagramID = ?", 1)
        .and_return([])

      result = transformer.transform(ea_diagram)

      expect(result).to be_a(Lutaml::Uml::Diagram)
      expect(result.name).to eq("Class Diagram")
      expect(result.xmi_id).to eq("EAID_DIAG_GUID")
      expect(result.package_id).to eq("5")
      expect(result.package_name).to eq("Domain")
      expect(result.definition).to eq("Main class diagram")
    end

    it "handles nil package_id" do
      ea_diagram = Lutaml::Qea::Models::EaDiagram.new(
        diagram_id: 1,
        name: "Diagram",
        package_id: nil,
      )

      allow(connection).to receive(:execute)
        .with("SELECT * FROM t_diagramobjects WHERE Diagram_ID = ?", 1)
        .and_return([])
      allow(connection).to receive(:execute)
        .with("SELECT * FROM t_diagramlinks WHERE DiagramID = ?", 1)
        .and_return([])

      result = transformer.transform(ea_diagram)

      expect(result.package_id).to be_nil
      expect(result.package_name).to be_nil
    end

    it "handles missing package" do
      ea_diagram = Lutaml::Qea::Models::EaDiagram.new(
        diagram_id: 1,
        name: "Diagram",
        package_id: 99,
      )

      allow(connection).to receive(:execute).and_return([])

      result = transformer.transform(ea_diagram)

      expect(result.package_id).to eq("99")
      expect(result.package_name).to be_nil
    end

    it "maps stereotype" do
      ea_diagram = Lutaml::Qea::Models::EaDiagram.new(
        diagram_id: 1,
        name: "Diagram",
        stereotype: "logical",
      )

      allow(connection).to receive(:execute).and_return([])

      result = transformer.transform(ea_diagram)

      expect(result.stereotype).to eq(["logical"])
    end

    it "skips empty notes" do
      ea_diagram = Lutaml::Qea::Models::EaDiagram.new(
        diagram_id: 1,
        name: "Diagram",
        notes: "",
      )

      allow(connection).to receive(:execute).and_return([])

      result = transformer.transform(ea_diagram)

      expect(result.definition).to be_nil
    end
  end
end
