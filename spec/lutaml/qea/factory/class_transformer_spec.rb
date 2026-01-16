# frozen_string_literal: true

require "spec_helper"
require_relative "../../../../lib/lutaml/qea/factory/class_transformer"
require_relative "../../../../lib/lutaml/qea/models/ea_object"

RSpec.describe Lutaml::Qea::Factory::ClassTransformer do
  let(:connection) { double("Connection") }
  let(:database) { double("Database", connection: connection) }
  let(:transformer) { described_class.new(database) }

  describe "#transform" do
    it "returns nil for nil input" do
      result = transformer.transform(nil)
      expect(result).to be_nil
    end

    it "returns nil for non-class objects" do
      ea_obj = Lutaml::Qea::Models::EaObject.new(
        object_type: "Package",
      )

      result = transformer.transform(ea_obj)

      expect(result).to be_nil
    end

    it "transforms EA class object to UML class" do
      ea_obj = Lutaml::Qea::Models::EaObject.new(
        ea_object_id: 1,
        object_type: "Class",
        name: "Building",
        ea_guid: "{CLASS-GUID}",
        abstract: "0",
        visibility: "Public",
        note: "Represents a building",
      )

      allow(connection).to receive(:execute).and_return([])
      allow(database).to receive(:xrefs).and_return(nil)
      allow(database).to receive(:tagged_values).and_return([])
      allow(connection).to receive(:execute)
        .with(
          "SELECT * FROM t_connector WHERE " \
          "(Start_Object_ID = ? OR End_Object_ID = ?) AND Connector_Type IN " \
          "('Association', 'Aggregation', 'Composition')", [1, 1]
        ).and_return([])
      allow(connection).to receive(:execute)
        .with("SELECT * FROM t_object WHERE Object_ID = ?", 1)
        .and_return([])
      allow(connection).to receive(:execute)
        .with(
          "SELECT ea_guid, End_Object_ID FROM t_connector WHERE " \
          "Start_Object_ID = ? AND Connector_Type = 'Generalization'", 1
        ).and_return([])
      allow(database).to receive(:attribute_tags).and_return([])
      allow(database).to receive(:object_constraints).and_return([])
      allow(database).to receive(:object_properties).and_return([])

      result = transformer.transform(ea_obj)

      expect(result).to be_a(Lutaml::Uml::Class)
      expect(result.name).to eq("Building")
      expect(result.xmi_id).to eq("EAID_CLASS_GUID")
      expect(result.is_abstract).to be false
      expect(result.visibility).to eq("public")
      expect(result.definition).to eq("Represents a building")
    end

    it "marks abstract classes" do
      ea_obj = Lutaml::Qea::Models::EaObject.new(
        object_id: 1,
        object_type: "Class",
        name: "Shape",
        abstract: "1",
      )

      allow(connection).to receive(:execute).and_return([])

      result = transformer.transform(ea_obj)

      expect(result.is_abstract).to be true
    end

    it "adds interface stereotype for interfaces" do
      ea_obj = Lutaml::Qea::Models::EaObject.new(
        ea_object_id: 1,
        object_type: "Interface",
        name: "IDrawable",
      )

      allow(connection).to receive(:execute).and_return([])
      allow(database).to receive(:xrefs).and_return(nil)
      allow(database).to receive(:tagged_values).and_return([])
      allow(connection).to receive(:execute)
        .with(
          "SELECT * FROM t_connector WHERE " \
          "(Start_Object_ID = ? OR End_Object_ID = ?) AND Connector_Type IN " \
          "('Association', 'Aggregation', 'Composition')", [1, 1]
        ).and_return([])
      allow(connection).to receive(:execute)
        .with("SELECT * FROM t_object WHERE Object_ID = ?", 1)
        .and_return([])
      allow(connection).to receive(:execute)
        .with(
          "SELECT ea_guid, End_Object_ID FROM t_connector WHERE " \
          "Start_Object_ID = ? AND Connector_Type = 'Generalization'", 1
        ).and_return([])
      allow(database).to receive(:attribute_tags).and_return([])
      allow(database).to receive(:object_constraints).and_return([])
      allow(database).to receive(:object_properties).and_return([])

      result = transformer.transform(ea_obj)

      expect(result.stereotype).to include("interface")
    end

    it "loads and transforms attributes" do
      ea_obj = Lutaml::Qea::Models::EaObject.new(
        ea_object_id: 1,
        object_type: "Class",
        name: "Person",
      )

      attr_row = {
        "ID" => 1,
        "Object_ID" => 1,
        "Name" => "firstName",
        "Type" => "String",
        "Scope" => "Private",
        "Pos" => 0,
      }

      allow(connection).to receive(:execute)
        .with(/SELECT.*t_attribute/, 1)
        .and_return([attr_row])
      allow(connection).to receive(:execute)
        .with(/SELECT.*t_operation/, 1)
        .and_return([])
      allow(connection).to receive(:execute)
        .with(
          "SELECT * FROM t_connector WHERE " \
          "(Start_Object_ID = ? OR End_Object_ID = ?) AND Connector_Type IN " \
          "('Association', 'Aggregation', 'Composition')", [1, 1]
        ).and_return([])
      allow(connection).to receive(:execute)
        .with("SELECT * FROM t_object WHERE Object_ID = ?", 1)
        .and_return([])
      allow(connection).to receive(:execute)
        .with(
          "SELECT ea_guid, End_Object_ID FROM t_connector WHERE " \
          "Start_Object_ID = ? AND Connector_Type = 'Generalization'", 1
        ).and_return([])
      allow(database).to receive(:attribute_tags).and_return([])
      allow(database).to receive(:object_constraints).and_return([])
      allow(database).to receive(:object_properties).and_return([])

      result = transformer.transform(ea_obj)

      expect(result.attributes.size).to eq(1)
      expect(result.attributes.first.name).to eq("firstName")
    end

    it "loads and transforms operations" do
      ea_obj = Lutaml::Qea::Models::EaObject.new(
        ea_object_id: 1,
        object_type: "Class",
        name: "Calculator",
      )

      op_row = {
        "OperationID" => 1,
        "Object_ID" => 1,
        "Name" => "add",
        "Type" => "Integer",
        "Scope" => "Public",
        "Pos" => 0,
      }

      allow(connection).to receive(:execute)
        .with(/SELECT.*t_attribute/, 1)
        .and_return([])
      allow(connection).to receive(:execute)
        .with(/SELECT.*t_operation/, 1)
        .and_return([op_row])
      allow(connection).to receive(:execute)
        .with(/SELECT.*t_operationparams/, 1)
        .and_return([])
      allow(connection).to receive(:execute)
        .with(
          "SELECT * FROM t_connector " \
          "WHERE (Start_Object_ID = ? OR End_Object_ID = ?) " \
          "AND Connector_Type " \
          "IN ('Association', 'Aggregation', 'Composition')",
          [1, 1],
        ).and_return([])
      allow(connection).to receive(:execute)
        .with("SELECT * FROM t_object WHERE Object_ID = ?", 1)
        .and_return([])
      allow(connection).to receive(:execute)
        .with(
          "SELECT ea_guid, End_Object_ID FROM t_connector WHERE " \
          "Start_Object_ID = ? AND Connector_Type = 'Generalization'", 1
        ).and_return([])
      allow(database).to receive(:attribute_tags).and_return([])
      allow(database).to receive(:object_constraints).and_return([])
      allow(database).to receive(:object_properties).and_return([])

      result = transformer.transform(ea_obj)

      expect(result.operations.size).to eq(1)
      expect(result.operations.first.name).to eq("add")
    end

    it "preserves stereotype" do
      ea_obj = Lutaml::Qea::Models::EaObject.new(
        object_id: 1,
        object_type: "Class",
        name: "Entity",
        stereotype: "entity",
      )

      allow(connection).to receive(:execute).and_return([])

      result = transformer.transform(ea_obj)

      expect(result.stereotype).to eq("entity")
    end
  end
end