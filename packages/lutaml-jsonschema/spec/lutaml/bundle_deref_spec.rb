# frozen_string_literal: true

require "spec_helper"

RSpec.describe "SchemaSet bundle and dereference modes" do
  def schema_set_from(hash, name = "demo")
    set = Lutaml::Jsonschema::SchemaSet.new
    set.add(name, Lutaml::Jsonschema::Schema.from_json(Yeptris::JSON.dump(hash)))
    set
  end

  describe "#bundle" do
    it "returns a combined Schema with hoisted definitions and localized refs" do
      set = schema_set_from(
        "definitions" => { "x" => { "type" => "string" } },
        "properties" => { "a" => { "$ref" => "#/definitions/x" } },
        "title" => "Demo",
      )
      combined = set.bundle
      json = Yeptris::JSON.load(combined.to_json)

      expect(combined).to be_a(Lutaml::Jsonschema::Schema)
      expect(json["$defs"].keys).to include("x")
      expect(json["properties"]["demo"]["$ref"]).to eq("#/$defs/demo")
    end

    it "keeps the Combiner facade in sync with the resolution layer" do
      set = schema_set_from(
        "definitions" => { "x" => { "type" => "string" } },
        "properties" => { "a" => { "$ref" => "#/definitions/x" } },
      )

      expect(Lutaml::Jsonschema::Combiner.new.combine(set).to_json)
        .to eq(set.bundle.to_json)
    end
  end

  describe "#dereference" do
    it "replaces internal references in place" do
      set = schema_set_from(
        "definitions" => { "x" => { "type" => "string" } },
        "properties" => { "a" => { "$ref" => "#/definitions/x" } },
      )
      result = set.dereference("demo")

      expect(result["properties"]["a"]).to eq("type" => "string")
      expect(result["$defs"]["x"]).to eq("type" => "string")
    end

    it "resolves nested references inside resolved targets" do
      set = schema_set_from(
        "definitions" => {
          "a" => { "properties" => { "b" => { "$ref" => "#/definitions/b" } } },
          "b" => { "type" => "integer" },
        },
        "properties" => { "root" => { "$ref" => "#/definitions/a" } },
      )
      result = set.dereference("demo")

      expect(result["properties"]["root"]["properties"]["b"])
        .to eq("type" => "integer")
    end

    it "leaves cyclic references as $ref nodes and terminates" do
      set = schema_set_from(
        "definitions" => {
          "a" => { "$ref" => "#/definitions/b" },
          "b" => { "$ref" => "#/definitions/a" },
        },
        "properties" => { "x" => { "$ref" => "#/definitions/a" } },
      )
      result = set.dereference("demo")

      expect(result["properties"]["x"]).to eq("$ref" => "#/definitions/a")
    end

    it "leaves external and unresolvable refs untouched" do
      set = schema_set_from(
        "properties" => {
          "ext" => { "$ref" => "./other.json#/definitions/x" },
          "missing" => { "$ref" => "#/definitions/nope" },
        },
      )
      result = set.dereference("demo")

      expect(result["properties"]["ext"])
        .to eq("$ref" => "./other.json#/definitions/x")
      expect(result["properties"]["missing"])
        .to eq("$ref" => "#/definitions/nope")
    end

    it "drops sibling keywords next to a replaced $ref" do
      set = schema_set_from(
        "definitions" => { "x" => { "type" => "string" } },
        "properties" => {
          "a" => { "$ref" => "#/definitions/x", "description" => "sibling" },
        },
      )
      result = set.dereference("demo")

      expect(result["properties"]["a"]).to eq("type" => "string")
    end

    it "raises for an unknown schema name" do
      set = schema_set_from("type" => "object")

      expect { set.dereference("nope") }
        .to raise_error(KeyError)
    end
  end
end
