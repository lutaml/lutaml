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

      current_obj = Lutaml::Qea::Models::EaObject.new(
        ea_object_id: 10,
        name: "SomeClass",
        object_type: "Class",
        ea_guid: "{SOME-GUID}",
      )

      result = transformer.transform(ea_conn, current_obj)

      expect(result).to be_nil
    end

    it "transforms EA generalization to UML generalization" do
      ea_conn = Lutaml::Qea::Models::EaConnector.new(
        connector_id: 1,
        connector_type: "Generalization",
        start_object_id: 10,
        end_object_id: 20,
        notes: "Inheritance relationship",
      )

      subtype_obj = Lutaml::Qea::Models::EaObject.new(
        ea_object_id: 10,
        name: "Car",
        object_type: "Class",
        ea_guid: "{CAR-GUID}",
      )

      supertype_obj = Lutaml::Qea::Models::EaObject.new(
        ea_object_id: 20,
        name: "Vehicle",
        ea_guid: "{VEHICLE-GUID}",
      )

      # The transformer calls find_package for the current object's package_id
      allow(database).to receive(:find_package).and_return(nil)

      # find_object_by_id is inherited from BaseTransformer which calls database.find_object
      allow(database).to receive(:find_object).with(20).and_return(supertype_obj)
      allow(database).to receive(:find_object).with(10).and_return(subtype_obj)

      current_obj = database.find_object(20)
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

      subtype_obj = Lutaml::Qea::Models::EaObject.new(
        ea_object_id: 10,
        name: "Subclass",
        object_type: "Class",
        ea_guid: "{SUB-GUID}",
      )

      allow(database).to receive(:find_package).and_return(nil)
      allow(database).to receive(:find_object).with(99).and_return(nil)
      allow(database).to receive(:find_object).with(10).and_return(subtype_obj)

      current_obj = database.find_object(99)
      result = transformer.transform(ea_conn, current_obj)

      expect(result).to be_nil
    end
  end
end
