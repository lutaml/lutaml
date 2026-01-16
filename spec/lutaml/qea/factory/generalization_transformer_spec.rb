# frozen_string_literal: true

require "spec_helper"
require_relative "../../../../lib/lutaml/qea/factory/generalization_transformer"
require_relative "../../../../lib/lutaml/qea/models/ea_connector"

RSpec.describe Lutaml::Qea::Factory::GeneralizationTransformer do
  let(:connection) { double("Connection") }
  let(:database) { double("Database", connection: connection) }
  let(:transformer) { described_class.new(database) }

  describe "#transform" do
    it "returns nil for nil input" do
      result = transformer.transform(nil, nil)
      expect(result).to be_nil
    end

    it "returns nil for non-generalization connectors" do
      ea_conn = Lutaml::Qea::Models::EaConnector.new(
        connector_type: "Association",
      )

      result = transformer.transform(ea_conn, nil)

      expect(result).to be_nil
    end

    it "transforms EA generalization to UML generalization" do
      ea_conn = Lutaml::Qea::Models::EaConnector.new(
        connector_id: 1,
        connector_type: "Generalization",
        start_object_id: 10,  # subtype
        end_object_id: 20,    # supertype
        notes: "Inheritance relationship",
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

      current_obj = transformer.send(:find_object_by_id, 20)
      result = transformer.transform(ea_conn, current_obj)

      expect(result).to be_a(Lutaml::Uml::Generalization)
      expect(result.general_id).to eq("EAID_VEHICLE_GUID")
      expect(result.general_name).to eq("Vehicle")
      expect(result.name).to eq("Vehicle")
      expect(result.type).to eq("uml:Generalization")
      expect(result.has_general).to be true
      expect(result.definition).to eq("Inheritance relationship")
    end

    it "handles missing supertype" do
      ea_conn = Lutaml::Qea::Models::EaConnector.new(
        connector_type: "Generalization",
        start_object_id: 10,
        end_object_id: 99,
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

      current_obj = transformer.send(:find_object_by_id, 99)
      result = transformer.transform(ea_conn, current_obj)

      expect(result).to be_nil
    end
  end
end