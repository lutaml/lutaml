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

      ea_package = Lutaml::Qea::Models::EaPackage.new(
        package_id: 5,
        name: "Domain",
        ea_guid: "{PKG-GUID}",
      )

      allow(database).to receive(:find_package).with(5).and_return(ea_package)
      allow(database).to receive(:diagram_objects_for).with(1).and_return([])
      allow(database).to receive(:diagram_links_for).with(1).and_return([])

      result = transformer.transform(ea_diagram)

      expect(result).to be_a(Lutaml::Uml::Diagram)
      expect(result.name).to eq("Class Diagram")
      expect(result.xmi_id).to eq("EAID_DIAG_GUID")
      expect(result.package_id).to eq("EAPK_PKG_GUID")
      expect(result.package_name).to eq("Domain")
      expect(result.definition).to eq("Main class diagram")
    end

    it "handles nil package_id" do
      ea_diagram = Lutaml::Qea::Models::EaDiagram.new(
        diagram_id: 1,
        name: "Diagram",
        package_id: nil,
      )

      allow(database).to receive(:diagram_objects_for).with(1).and_return([])
      allow(database).to receive(:diagram_links_for).with(1).and_return([])

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

      allow(database).to receive(:find_package).with(99).and_return(nil)
      allow(database).to receive(:diagram_objects_for).with(1).and_return([])
      allow(database).to receive(:diagram_links_for).with(1).and_return([])

      result = transformer.transform(ea_diagram)

      expect(result.package_id).to be_nil
      expect(result.package_name).to be_nil
    end

    it "maps stereotype" do
      ea_diagram = Lutaml::Qea::Models::EaDiagram.new(
        diagram_id: 1,
        name: "Diagram",
        stereotype: "logical",
      )

      allow(database).to receive(:diagram_objects_for).with(1).and_return([])
      allow(database).to receive(:diagram_links_for).with(1).and_return([])

      result = transformer.transform(ea_diagram)

      expect(result.stereotype).to eq(["logical"])
    end

    it "skips empty notes" do
      ea_diagram = Lutaml::Qea::Models::EaDiagram.new(
        diagram_id: 1,
        name: "Diagram",
        notes: "",
      )

      allow(database).to receive(:diagram_objects_for).with(1).and_return([])
      allow(database).to receive(:diagram_links_for).with(1).and_return([])

      result = transformer.transform(ea_diagram)

      expect(result.definition).to be_nil
    end
  end
end
