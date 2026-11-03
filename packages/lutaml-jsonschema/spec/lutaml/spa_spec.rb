# frozen_string_literal: true

require "spec_helper"

RSpec.describe Lutaml::Jsonschema::Spa::SpaDocument do
  let(:fixtures_dir) { File.join(__dir__, "..", "fixtures") }
  let(:schema_set) do
    Lutaml::Jsonschema::SchemaSet.load_from_files(
      File.join(fixtures_dir, "person.json"),
    )
  end

  describe ".from_schema_set" do
    subject(:doc) { described_class.from_schema_set(schema_set) }

    it "creates a SpaDocument with metadata" do
      expect(doc.metadata).not_to be_nil
    end

    it "creates SpaSchema entries for each schema" do
      expect(doc.schemas.length).to eq(1)
      expect(doc.schemas.first.name).to eq("person")
      expect(doc.schemas.first.title).to eq("Person")
    end

    it "maps property entries to SpaProperty" do
      schema = doc.schemas.first
      expect(schema.properties.length).to eq(6)
      first_name = schema.properties.find { |p| p.name == "firstName" }
      expect(first_name.type).to eq("string")
      expect(first_name.required).to eq(true)
      expect(first_name.description).to eq("The person's first name.")
    end

    it "marks properties as required" do
      schema = doc.schemas.first
      last_name = schema.properties.find { |p| p.name == "lastName" }
      expect(last_name.required).to eq(true)
      age = schema.properties.find { |p| p.name == "age" }
      expect(age.required).to eq(false)
    end

    it "maps definition entries" do
      schema = doc.schemas.first
      expect(schema.definitions.length).to eq(1)
      expect(schema.definitions.first.name).to eq("address")
    end

    it "creates search index entries" do
      expect(doc.search_index.length).to be > 0
      schema_entry = doc.search_index.find { |e| e.type == "schema" }
      expect(schema_entry.name).to eq("person")
    end
  end

  describe "#to_json (serialization)" do
    it "produces valid JSON" do
      doc = described_class.from_schema_set(schema_set)
      json = doc.to_json
      parsed = JSON.parse(json)

      expect(parsed).to have_key("metadata")
      expect(parsed).to have_key("schemas")
      expect(parsed).to have_key("searchIndex")
      expect(parsed["schemas"]).to be_a(Array)
      expect(parsed["schemas"].first["name"]).to eq("person")
    end

    it "round-trips through JSON" do
      doc = described_class.from_schema_set(schema_set)
      json = doc.to_json
      reparsed = described_class.from_json(json)

      expect(reparsed.metadata).not_to be_nil
      expect(reparsed.schemas.length).to eq(doc.schemas.length)
      expect(reparsed.schemas.first.name).to eq("person")
    end
  end
end

RSpec.describe Lutaml::Jsonschema::Spa::SpaProperty do
  it "serializes to JSON with expected keys" do
    prop = described_class.new(
      name: "id",
      type: "string",
      format: "uuid",
      required: true,
    )
    json = prop.to_json
    parsed = JSON.parse(json)

    expect(parsed["name"]).to eq("id")
    expect(parsed["type"]).to eq("string")
    expect(parsed["format"]).to eq("uuid")
    expect(parsed["required"]).to eq(true)
  end

  it "serializes readOnly and writeOnly" do
    prop = described_class.new(
      name: "created_at",
      type: "string",
      read_only: true,
    )
    parsed = JSON.parse(prop.to_json)
    expect(parsed["readOnly"]).to eq(true)
    expect(parsed["writeOnly"]).to be_nil
  end

  it "serializes array constraints" do
    prop = described_class.new(
      name: "tags",
      type: "array",
      min_items: 1,
      max_items: 10,
      unique_items: true,
    )
    parsed = JSON.parse(prop.to_json)
    expect(parsed["minItems"]).to eq(1)
    expect(parsed["maxItems"]).to eq(10)
    expect(parsed["uniqueItems"]).to eq(true)
  end

  it "serializes const value" do
    prop = described_class.new(
      name: "version",
      type: "string",
      const_value: "1.0",
    )
    parsed = JSON.parse(prop.to_json)
    expect(parsed["const"]).to eq("1.0")
  end

  it "serializes multipleOf" do
    prop = described_class.new(
      name: "price",
      type: "number",
      multiple_of: 0.01,
    )
    parsed = JSON.parse(prop.to_json)
    expect(parsed["multipleOf"]).to eq(0.01)
  end

  it "serializes exclusiveMinimum and exclusiveMaximum" do
    prop = described_class.new(
      name: "score",
      type: "number",
      exclusive_minimum: 0.0,
      exclusive_maximum: 100.0,
    )
    parsed = JSON.parse(prop.to_json)
    expect(parsed["exclusiveMinimum"]).to eq(0.0)
    expect(parsed["exclusiveMaximum"]).to eq(100.0)
  end

  it "serializes additionalProperties" do
    prop = described_class.new(
      name: "metadata",
      type: "object",
      additional_properties: false,
    )
    parsed = JSON.parse(prop.to_json)
    expect(parsed["additionalProperties"]).to eq(false)
  end

  it "serializes contentMediaType and contentEncoding" do
    prop = described_class.new(
      name: "html_content",
      type: "string",
      content_type: "text/html",
      content_encoding: "base64",
    )
    parsed = JSON.parse(prop.to_json)
    expect(parsed["contentMediaType"]).to eq("text/html")
    expect(parsed["contentEncoding"]).to eq("base64")
  end

  it "serializes compositionSource" do
    prop = described_class.new(
      name: "email",
      type: "string",
      composition_source: "allOf",
    )
    parsed = JSON.parse(prop.to_json)
    expect(parsed["compositionSource"]).to eq("allOf")
  end
end

RSpec.describe Lutaml::Jsonschema::Spa::SpaSchema do
  it "serializes minProperties and maxProperties" do
    schema = described_class.new(
      name: "person",
      type: "object",
      min_properties: 1,
      max_properties: 10,
    )
    parsed = JSON.parse(schema.to_json)
    expect(parsed["minProperties"]).to eq(1)
    expect(parsed["maxProperties"]).to eq(10)
  end

  it "serializes composition flags" do
    schema = described_class.new(
      name: "mixed",
      type: "object",
      has_all_of: true,
      has_any_of: false,
      has_one_of: true,
    )
    parsed = JSON.parse(schema.to_json)
    expect(parsed["hasAllOf"]).to eq(true)
    expect(parsed["hasAnyOf"]).to eq(false)
    expect(parsed["hasOneOf"]).to eq(true)
  end
end
