# frozen_string_literal: true

require "spec_helper"

RSpec.describe "SPA change projection" do
  def schema(hash)
    Lutaml::Jsonschema::Schema.from_json(Yeptris::JSON.dump(hash))
  end

  def schema_set(hash, name = "demo")
    set = Lutaml::Jsonschema::SchemaSet.new
    set.add(name, schema(hash))
    set
  end

  let(:baseline_hash) do
    {
      "type" => "object",
      "properties" => {
        "a" => { "type" => "string" },
        "b" => { "type" => "integer" },
      },
    }
  end

  let(:current_hash) do
    {
      "type" => "object",
      "properties" => {
        "a" => { "type" => "integer" },
        "b" => { "type" => "integer" },
      },
    }
  end

  it "classifies changes against a baseline set" do
    document = Lutaml::Jsonschema::Spa::SpaBuilder.new(
      schema_set(current_hash), baseline: schema_set(baseline_hash)
    ).build

    expect(document.diff.map do |entry|
      [entry.schema_name, entry.pointer, entry.classification]
    end).to include(["demo", "/properties/a/type", "breaking"])
  end

  it "is empty without a baseline" do
    document = Lutaml::Jsonschema::Spa::SpaBuilder.new(
      schema_set(current_hash),
    ).build

    expect(document.diff).to eq([])
  end

  it "is empty for a schema absent from the baseline" do
    document = Lutaml::Jsonschema::Spa::SpaBuilder.new(
      schema_set(current_hash), baseline: schema_set(baseline_hash, "other")
    ).build

    expect(document.diff).to eq([])
  end

  it "emits the diff in the serialized document" do
    document = Lutaml::Jsonschema::Spa::SpaBuilder.new(
      schema_set(current_hash), baseline: schema_set(baseline_hash)
    ).build
    json = Yeptris::JSON.load(document.to_json)

    expect(json["diff"].first).to include(
      "schemaName" => "demo",
      "pointer" => "/properties/a/type",
      "classification" => "breaking",
    )
  end
end
