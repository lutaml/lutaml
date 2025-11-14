# frozen_string_literal: true

require "spec_helper"
require "lutaml/qea/models/ea_connector"

RSpec.describe Lutaml::Qea::Models::EaConnector do
  describe ".primary_key_column" do
    it "returns :connector_id" do
      expect(described_class.primary_key_column).to eq(:connector_id)
    end
  end

  describe ".table_name" do
    it "returns 't_connector'" do
      expect(described_class.table_name).to eq("t_connector")
    end
  end

  describe "#primary_key" do
    it "returns connector_id value" do
      conn = described_class.new(connector_id: 123)
      expect(conn.primary_key).to eq(123)
    end
  end

  describe "attribute access" do
    it "allows reading and writing connector_id" do
      conn = described_class.new(connector_id: 456)
      expect(conn.connector_id).to eq(456)
    end

    it "allows reading and writing name" do
      conn = described_class.new(name: "MyAssociation")
      expect(conn.name).to eq("MyAssociation")
    end

    it "allows reading and writing connector_type" do
      conn = described_class.new(connector_type: "Association")
      expect(conn.connector_type).to eq("Association")
    end

    it "allows reading and writing start_object_id" do
      conn = described_class.new(start_object_id: 789)
      expect(conn.start_object_id).to eq(789)
    end

    it "allows reading and writing end_object_id" do
      conn = described_class.new(end_object_id: 101)
      expect(conn.end_object_id).to eq(101)
    end

    it "allows reading and writing ea_guid" do
      conn = described_class.new(ea_guid: "{GUID}")
      expect(conn.ea_guid).to eq("{GUID}")
    end
  end

  describe "#association?" do
    it "returns true when connector_type is 'Association'" do
      conn = described_class.new(connector_type: "Association")
      expect(conn).to be_association
    end

    it "returns false when connector_type is not 'Association'" do
      conn = described_class.new(connector_type: "Generalization")
      expect(conn).not_to be_association
    end
  end

  describe "#generalization?" do
    it "returns true when connector_type is 'Generalization'" do
      conn = described_class.new(connector_type: "Generalization")
      expect(conn).to be_generalization
    end

    it "returns false when connector_type is not 'Generalization'" do
      conn = described_class.new(connector_type: "Association")
      expect(conn).not_to be_generalization
    end
  end

  describe "#dependency?" do
    it "returns true when connector_type is 'Dependency'" do
      conn = described_class.new(connector_type: "Dependency")
      expect(conn).to be_dependency
    end

    it "returns false when connector_type is not 'Dependency'" do
      conn = described_class.new(connector_type: "Association")
      expect(conn).not_to be_dependency
    end
  end

  describe "#aggregation?" do
    it "returns true when connector_type is 'Aggregation'" do
      conn = described_class.new(connector_type: "Aggregation")
      expect(conn).to be_aggregation
    end

    it "returns false when connector_type is not 'Aggregation'" do
      conn = described_class.new(connector_type: "Association")
      expect(conn).not_to be_aggregation
    end
  end

  describe "#realization?" do
    it "returns true when connector_type is 'Realization'" do
      conn = described_class.new(connector_type: "Realization")
      expect(conn).to be_realization
    end

    it "returns false when connector_type is not 'Realization'" do
      conn = described_class.new(connector_type: "Association")
      expect(conn).not_to be_realization
    end
  end

  describe "#source_aggregate?" do
    it "returns true when sourceisaggregate is 1" do
      conn = described_class.new(sourceisaggregate: 1)
      expect(conn).to be_source_aggregate
    end

    it "returns false when sourceisaggregate is 0" do
      conn = described_class.new(sourceisaggregate: 0)
      expect(conn).not_to be_source_aggregate
    end
  end

  describe "#dest_aggregate?" do
    it "returns true when destisaggregate is 1" do
      conn = described_class.new(destisaggregate: 1)
      expect(conn).to be_dest_aggregate
    end

    it "returns false when destisaggregate is 0" do
      conn = described_class.new(destisaggregate: 0)
      expect(conn).not_to be_dest_aggregate
    end
  end

  describe "#source_navigable?" do
    it "returns true when sourceisnavigable is 1" do
      conn = described_class.new(sourceisnavigable: 1)
      expect(conn).to be_source_navigable
    end

    it "returns false when sourceisnavigable is 0" do
      conn = described_class.new(sourceisnavigable: 0)
      expect(conn).not_to be_source_navigable
    end
  end

  describe "#dest_navigable?" do
    it "returns true when destisnavigable is 1" do
      conn = described_class.new(destisnavigable: 1)
      expect(conn).to be_dest_navigable
    end

    it "returns false when destisnavigable is 0" do
      conn = described_class.new(destisnavigable: 0)
      expect(conn).not_to be_dest_navigable
    end
  end

  describe "#bold?" do
    it "returns true when isbold is 1" do
      conn = described_class.new(isbold: 1)
      expect(conn).to be_bold
    end

    it "returns false when isbold is 0" do
      conn = described_class.new(isbold: 0)
      expect(conn).not_to be_bold
    end
  end

  describe ".from_db_row" do
    it "creates instance from database row" do
      row = {
        "Connector_ID" => 123,
        "Name" => "association",
        "Connector_Type" => "Association",
        "Start_Object_ID" => 456,
        "End_Object_ID" => 789,
        "ea_guid" => "{GUID}",
      }

      conn = described_class.from_db_row(row)

      expect(conn.connector_id).to eq(123)
      expect(conn.name).to eq("association")
      expect(conn.connector_type).to eq("Association")
      expect(conn.start_object_id).to eq(456)
      expect(conn.end_object_id).to eq(789)
      expect(conn.ea_guid).to eq("{GUID}")
    end
  end

  describe "inheritance" do
    it "inherits from BaseModel" do
      expect(described_class).to be < Lutaml::Qea::Models::BaseModel
    end
  end
end