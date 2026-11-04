# frozen_string_literal: true

require "spec_helper"

RSpec.describe Lutaml::Jsonschema::Spa::SpaSearchEntry do
  describe "JSON serialization" do
    it "serializes all fields with camelCase keys" do
      entry = described_class.new(
        name: "address",
        title: "Address",
        description: "A postal address",
        type: "definition",
        schema_name: "person",
      )
      parsed = JSON.parse(entry.to_json)
      expect(parsed["name"]).to eq("address")
      expect(parsed["title"]).to eq("Address")
      expect(parsed["description"]).to eq("A postal address")
      expect(parsed["type"]).to eq("definition")
      expect(parsed["schemaName"]).to eq("person")
    end

    it "round-trips through JSON" do
      entry = described_class.new(
        name: "firstName",
        type: "property",
        schema_name: "person",
      )
      reparsed = described_class.from_json(entry.to_json)
      expect(reparsed.name).to eq("firstName")
      expect(reparsed.type).to eq("property")
      expect(reparsed.schema_name).to eq("person")
    end
  end
end
