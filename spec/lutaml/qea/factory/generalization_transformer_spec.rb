# frozen_string_literal: true

require "spec_helper"
require "lutaml/qea/factory/generalization_transformer"
require "lutaml/qea/models/ea_connector"

RSpec.describe Lutaml::Qea::Factory::GeneralizationTransformer do
  let(:connection) { double("Connection") }
  let(:database) { double("Database", connection: connection) }
  let(:transformer) { described_class.new(database) }

  describe "#transform" do
    it "returns nil for nil input" do
      result = transformer.transform(nil)
      expect(result).to be_nil
    end

    it "returns nil for non-generalization connectors" do
      ea_conn = Lutaml::Qea::Models::EaConnector.new(
        connector_type: "Association"
      )

      result = transformer.transform(ea_conn)

      expect(result).to be_nil
    end

    it "transforms EA generalization to UML generalization" do
      ea_conn = Lutaml::Qea::Models::EaConnector.new(
        connector_id: 1,
        connector_type: "Generalization",
        start_object_id: 10,  # subtype
        end_object_id: 20,    # supertype
        notes: "Inheritance relationship"
      )

      subtype_row = {
        "Object_ID" => 10,
        "Name" => "Car",
        "Object_Type" => "Class",
        "ea_guid" => "{CAR-GUID}",
      }

      supertype_row = {
        "Object_ID" => 20,
        "Name" => "Vehicle",
        "ea_guid" => "{VEHICLE-GUID}",
      }

      allow(connection).to receive(:execute)
        .with(/SELECT.*t_object.*Object_ID = \?/, 10)
        .and_return([subtype_row])
      allow(connection).to receive(:execute)
        .with(/SELECT.*t_object.*Object_ID = \?/, 20)
        .and_return([supertype_row])

      result = transformer.transform(ea_conn)

      expect(result).to be_a(Lutaml::Uml::Generalization)
      expect(result.general_id).to eq("{VEHICLE-GUID}")
      expect(result.general_name).to eq("Vehicle")
      expect(result.name).to eq("Car")
      expect(result.type).to eq("Class")
      expect(result.has_general).to be true
      expect(result.definition).to eq("Inheritance relationship")
    end

    it "handles missing supertype" do
      ea_conn = Lutaml::Qea::Models::EaConnector.new(
        connector_type: "Generalization",
        start_object_id: 10,
        end_object_id: 99
      )

      subtype_row = {
        "Object_ID" => 10,
        "Name" => "Subclass",
        "Object_Type" => "Class",
        "ea_guid" => "{SUB-GUID}",
      }

      allow(connection).to receive(:execute)
        .with(/SELECT.*t_object.*Object_ID = \?/, 10)
        .and_return([subtype_row])
      allow(connection).to receive(:execute)
        .with(/SELECT.*t_object.*Object_ID = \?/, 99)
        .and_return([])

      result = transformer.transform(ea_conn)

      expect(result.name).to eq("Subclass")
      expect(result.general_id).to be_nil
      expect(result.general_name).to be_nil
      expect(result.has_general).to be false
    end

    it "maps stereotype" do
      ea_conn = Lutaml::Qea::Models::EaConnector.new(
        connector_type: "Generalization",
        start_object_id: 10,
        end_object_id: 20,
        stereotype: "implementation"
      )

      allow(connection).to receive(:execute).and_return([])

      result = transformer.transform(ea_conn)

      expect(result.stereotype).to eq("implementation")
    end
  end
end