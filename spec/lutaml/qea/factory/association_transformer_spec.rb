# frozen_string_literal: true

require "spec_helper"
require_relative "../../../../lib/lutaml/qea/factory/association_transformer"
require_relative "../../../../lib/lutaml/qea/models/ea_connector"

RSpec.describe Lutaml::Qea::Factory::AssociationTransformer do
  let(:connection) { double("Connection") }
  let(:database) { double("Database", connection: connection) }
  let(:transformer) { described_class.new(database) }

  describe "#transform" do
    it "returns nil for nil input" do
      result = transformer.transform(nil)
      expect(result).to be_nil
    end

    it "returns nil for non-association connectors" do
      ea_conn = Lutaml::Qea::Models::EaConnector.new(
        connector_type: "Generalization",
      )

      result = transformer.transform(ea_conn)

      expect(result).to be_nil
    end

    it "transforms EA association to UML association" do
      ea_conn = Lutaml::Qea::Models::EaConnector.new(
        connector_id: 1,
        connector_type: "Association",
        name: "owns",
        ea_guid: "{ASSOC-GUID}",
        start_object_id: 10,
        end_object_id: 20,
        sourcerole: "owner",
        destrole: "property",
        sourcecard: "1",
        destcard: "0..*",
        notes: "Ownership relationship",
      )

      source_obj_row = {
        "Object_ID" => 10,
        "Name" => "Person",
        "ea_guid" => "{PERSON-GUID}",
      }

      dest_obj_row = {
        "Object_ID" => 20,
        "Name" => "Building",
        "ea_guid" => "{BUILDING-GUID}",
      }

      allow(connection).to receive(:execute)
        .with(/SELECT.*t_object.*Object_ID = \?/, 10)
        .and_return([source_obj_row])
      allow(connection).to receive(:execute)
        .with(/SELECT.*t_object.*Object_ID = \?/, 20)
        .and_return([dest_obj_row])
      allow(database).to receive(:tagged_values).and_return([])

      result = transformer.transform(ea_conn)

      expect(result).to be_a(Lutaml::Uml::Association)
      expect(result.name).to eq("owns")
      expect(result.xmi_id).to eq("EAID_ASSOC_GUID")
      expect(result.owner_end).to eq("Person")
      expect(result.member_end).to eq("Building")
      expect(result.owner_end_attribute_name).to eq("owner")
      expect(result.member_end_attribute_name).to eq("property")
      expect(result.definition).to eq("Ownership relationship")
    end

    it "builds cardinality for source end" do
      ea_conn = Lutaml::Qea::Models::EaConnector.new(
        connector_type: "Association",
        start_object_id: 10,
        end_object_id: 20,
        sourcecard: "1..*",
      )

      source_obj_row = {
        "Object_ID" => 10,
        "Name" => "Class1",
        "ea_guid" => "{GUID1}",
      }

      dest_obj_row = {
        "Object_ID" => 20,
        "Name" => "Class2",
        "ea_guid" => "{GUID2}",
      }

      allow(connection).to receive(:execute)
        .with(/SELECT.*t_object.*Object_ID = \?/, 10)
        .and_return([source_obj_row])
      allow(connection).to receive(:execute)
        .with(/SELECT.*t_object.*Object_ID = \?/, 20)
        .and_return([dest_obj_row])

      result = transformer.transform(ea_conn)

      expect(result.owner_end_cardinality).to be_a(Lutaml::Uml::Cardinality)
      expect(result.owner_end_cardinality.min).to eq("1")
      expect(result.owner_end_cardinality.max).to eq("*")
    end

    it "handles missing object gracefully" do
      ea_conn = Lutaml::Qea::Models::EaConnector.new(
        connector_type: "Association",
        start_object_id: 99,
        end_object_id: nil,
      )

      allow(connection).to receive(:execute).and_return([])

      result = transformer.transform(ea_conn)

      expect(result).to be_a(Lutaml::Uml::Association)
      expect(result.owner_end).to be_nil
      expect(result.member_end).to be_nil
    end

    it "maps stereotype" do
      ea_conn = Lutaml::Qea::Models::EaConnector.new(
        connector_type: "Association",
        start_object_id: 10,
        end_object_id: 20,
        stereotype: "create",
      )

      allow(connection).to receive(:execute).and_return([])

      result = transformer.transform(ea_conn)

      expect(result.stereotype).to eq(["create"])
    end
  end
end