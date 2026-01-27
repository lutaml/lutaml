# frozen_string_literal: true

require "spec_helper"
require_relative "../../../../lib/lutaml/qea/factory/package_transformer"
require_relative "../../../../lib/lutaml/qea/models/ea_package"

RSpec.describe Lutaml::Qea::Factory::PackageTransformer do
  let(:connection) { double("Connection") }
  let(:database) { double("Database", connection: connection) }
  let(:transformer) { described_class.new(database) }

  describe "#transform" do
    it "returns nil for nil input" do
      result = transformer.transform(nil)
      expect(result).to be_nil
    end

    it "transforms EA package to UML package" do
      ea_pkg = Lutaml::Qea::Models::EaPackage.new(
        package_id: 1,
        name: "Domain",
        ea_guid: "{PKG-GUID}",
        notes: "Domain model package",
      )

      allow(database).to receive(:xrefs).and_return(nil)
      result = transformer.transform(ea_pkg)

      expect(result).to be_a(Lutaml::Uml::Package)
      expect(result.name).to eq("Domain")
      expect(result.xmi_id).to eq("EAPK_PKG_GUID")
      expect(result.definition).to eq("Domain model package")
      expect(result.packages).to eq([])
      expect(result.classes).to eq([])
    end

    it "skips empty notes" do
      ea_pkg = Lutaml::Qea::Models::EaPackage.new(
        package_id: 1,
        name: "Package",
        notes: "",
      )

      result = transformer.transform(ea_pkg)

      expect(result.definition).to be_nil
    end
  end

  describe "#transform_with_hierarchy" do
    it "loads child packages" do
      ea_pkg = Lutaml::Qea::Models::EaPackage.new(
        package_id: 1,
        name: "Root",
      )

      child_row = {
        "Package_ID" => 2,
        "Name" => "Child",
        "Parent_ID" => 1,
        "ea_guid" => "{CHILD-GUID}",
      }

      allow(connection).to receive(:execute)
        .with(/SELECT.*t_package.*Parent_ID/, 1)
        .and_return([child_row])
      allow(connection).to receive(:execute)
        .with(/SELECT.*t_package.*Parent_ID/, 2)
        .and_return([])
      allow(connection).to receive(:execute)
        .with(/SELECT.*t_object/, anything)
        .and_return([])
      allow(connection).to receive(:execute)
        .with(/SELECT.*t_diagram/, anything)
        .and_return([])
      allow(database).to receive(:xrefs).and_return(nil)

      result = transformer.transform_with_hierarchy(ea_pkg)

      expect(result.packages.size).to eq(1)
      expect(result.packages.first.name).to eq("Child")
    end

    it "loads package objects as classes" do
      ea_pkg = Lutaml::Qea::Models::EaPackage.new(
        package_id: 1,
        name: "Models",
      )

      class_row = {
        "Object_ID" => 10,
        "Object_Type" => "Class",
        "Name" => "Entity",
        "Package_ID" => 1,
      }

      allow(connection).to receive(:execute)
        .with(/SELECT.*t_package/, 1)
        .and_return([])
      allow(connection).to receive(:execute)
        .with(/SELECT.*t_object.*Package_ID/, 1)
        .and_return([class_row])
      allow(connection).to receive(:execute)
        .with(/SELECT.*t_attribute/, 10)
        .and_return([])
      allow(connection).to receive(:execute)
        .with(/SELECT.*t_operation/, 10)
        .and_return([])
      allow(connection).to receive(:execute)
        .with(/SELECT.*t_diagram/, 1)
        .and_return([])
      allow(connection).to receive(:execute)
        .with(/SELECT.*t_connector/, [10, 10])
        .and_return([])
      allow(connection).to receive(:execute)
        .with("SELECT * FROM t_object WHERE Object_ID = ?", 10)
        .and_return([class_row])
      allow(connection).to receive(:execute)
        .with("SELECT NAME FROM t_package WHERE Package_ID = ?", [1])
        .and_return([])
      allow(connection).to receive(:execute)
        .with(
          "SELECT * FROM t_connector WHERE Start_Object_ID = ? " \
          "AND Connector_Type = 'Generalization' LIMIT 1", 10
        ).and_return([])
      allow(connection)
        .to receive(:execute)
        .with(
          "SELECT ea_guid, End_Object_ID FROM t_connector " \
          "WHERE Start_Object_ID = ? AND Connector_Type = 'Generalization'", 10
        ).and_return([])

      allow(database).to receive(:object_constraints).and_return([])
      allow(database).to receive(:object_properties).and_return([])
      allow(database).to receive(:packages).and_return([])
      allow(database).to receive(:xrefs).and_return(nil)

      result = transformer.transform_with_hierarchy(ea_pkg)

      expect(result.classes.size).to eq(1)
      expect(result.classes.first.name).to eq("Entity")
    end

    it "loads package diagrams" do
      ea_pkg = Lutaml::Qea::Models::EaPackage.new(
        package_id: 1,
        name: "Views",
      )

      diagram_row = {
        "Diagram_ID" => 5,
        "Package_ID" => 1,
        "Name" => "Class Diagram",
      }

      allow(connection).to receive(:execute)
        .with(/SELECT.*t_package/, 1)
        .and_return([])
      allow(connection).to receive(:execute)
        .with(/SELECT.*t_object/, 1)
        .and_return([])
      allow(connection).to receive(:execute)
        .with(/SELECT.*t_diagram.*Package_ID/, 1)
        .and_return([diagram_row])
      allow(connection).to receive(:execute)
        .with(/SELECT.*t_package.*Package_ID/, 1)
        .and_return([])
      allow(connection).to receive(:execute)
        .with("SELECT * FROM t_diagramobjects WHERE Diagram_ID = ?", 5)
        .and_return([])
      allow(connection).to receive(:execute)
        .with("SELECT * FROM t_diagramlinks WHERE DiagramID = ?", 5)
        .and_return([])
      allow(database).to receive(:object_constraints).and_return([])
      allow(database).to receive(:object_properties).and_return([])
      allow(database).to receive(:packages).and_return([])
      allow(database).to receive(:xrefs).and_return(nil)

      result = transformer.transform_with_hierarchy(ea_pkg)

      expect(result.diagrams.size).to eq(1)
      expect(result.diagrams.first.name).to eq("Class Diagram")
    end
  end
end
