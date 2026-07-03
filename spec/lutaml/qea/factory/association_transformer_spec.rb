# frozen_string_literal: true

require "spec_helper"
require_relative "../../../../lib/lutaml/qea/factory/association_transformer"
require_relative "../../../../lib/lutaml/qea/models/ea_connector"

RSpec.describe Lutaml::Qea::Factory::AssociationTransformer do
  let(:connection) { double("Connection") }
  let(:database) { double("Database", connection: connection) }
  let(:transformer) { described_class.new(database) }

  describe "#transform" do
    let(:source_obj) do
      Lutaml::Qea::Models::EaObject.new(
        ea_object_id: 10, name: "Person", ea_guid: "{PERSON-GUID}",
      )
    end
    let(:dest_obj) do
      Lutaml::Qea::Models::EaObject.new(
        ea_object_id: 20, name: "Building", ea_guid: "{BUILDING-GUID}",
      )
    end
    let(:ea_conn) do
      Lutaml::Qea::Models::EaConnector.new(
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
    end

    before do
      allow(database).to receive(:find_object).with(10).and_return(source_obj)
      allow(database).to receive(:find_object).with(20).and_return(dest_obj)
      allow(database).to receive(:tagged_values).and_return([])
    end

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

    it "transforms EA association to UML association", :aggregate_failures do
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

    it "builds cardinality for source end", :aggregate_failures do
      ea_conn = Lutaml::Qea::Models::EaConnector.new(
        connector_type: "Association",
        start_object_id: 10,
        end_object_id: 20,
        sourcecard: "1..*",
      )

      source_obj = Lutaml::Qea::Models::EaObject.new(
        ea_object_id: 10,
        name: "Class1",
        ea_guid: "{GUID1}",
      )

      dest_obj = Lutaml::Qea::Models::EaObject.new(
        ea_object_id: 20,
        name: "Class2",
        ea_guid: "{GUID2}",
      )

      allow(database).to receive(:find_object).with(10).and_return(source_obj)
      allow(database).to receive(:find_object).with(20).and_return(dest_obj)

      result = transformer.transform(ea_conn)

      expect(result.owner_end_cardinality).to be_a(Lutaml::Uml::Cardinality)
      expect(result.owner_end_cardinality.min).to eq("1")
      expect(result.owner_end_cardinality.max).to eq("*")
    end

    it "handles missing object gracefully", :aggregate_failures do
      ea_conn = Lutaml::Qea::Models::EaConnector.new(
        connector_type: "Association",
        start_object_id: 99,
        end_object_id: nil,
      )

      allow(database).to receive(:find_object).with(99).and_return(nil)

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

      allow(database).to receive(:find_object).with(10).and_return(nil)
      allow(database).to receive(:find_object).with(20).and_return(nil)

      result = transformer.transform(ea_conn)

      expect(result.stereotype).to eq(["create"])
    end
  end
end
