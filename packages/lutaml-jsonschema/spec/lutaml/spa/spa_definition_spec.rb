# frozen_string_literal: true

require "spec_helper"

RSpec.describe Lutaml::Jsonschema::Spa::SpaDefinition do
  describe "JSON serialization" do
    it "serializes all constraint fields" do
      defn = described_class.new(
        name: "Address",
        title: "Address Type",
        type: "object",
        format: nil,
        enum: [],
        const_value: nil,
        pattern: nil,
        min_length: 1,
        max_length: 200,
        minimum: 0.0,
        maximum: 100.0,
        exclusive_minimum: nil,
        exclusive_maximum: nil,
        multiple_of: nil,
      )
      parsed = JSON.parse(defn.to_json)
      expect(parsed["name"]).to eq("Address")
      expect(parsed["type"]).to eq("object")
      expect(parsed["minLength"]).to eq(1)
      expect(parsed["maxLength"]).to eq(200)
      expect(parsed["minimum"]).to eq(0.0)
      expect(parsed["maximum"]).to eq(100.0)
    end

    it "serializes composition flags" do
      defn = described_class.new(
        name: "mixed",
        has_all_of: true,
        has_any_of: false,
        has_one_of: true,
      )
      parsed = JSON.parse(defn.to_json)
      expect(parsed["hasAllOf"]).to eq(true)
      expect(parsed["hasAnyOf"]).to eq(false)
      expect(parsed["hasOneOf"]).to eq(true)
    end

    it "serializes items detail" do
      prop = Lutaml::Jsonschema::Spa::SpaProperty.new(name: "item",
                                                      type: "string")
      defn = described_class.new(
        name: "TagList",
        type: "array",
        items_type: "string",
        items_ref: "#/$defs/Tag",
        items_properties: [prop],
        items_required: ["item"],
        items_enum: %w[a b c],
        items_format: "email",
      )
      parsed = JSON.parse(defn.to_json)
      expect(parsed["itemsType"]).to eq("string")
      expect(parsed["itemsRef"]).to eq("#/$defs/Tag")
      expect(parsed["itemsProperties"].length).to eq(1)
      expect(parsed["itemsRequired"]).to eq(["item"])
      expect(parsed["itemsEnum"]).to eq(%w[a b c])
      expect(parsed["itemsFormat"]).to eq("email")
    end

    it "serializes variant and feature fields" do
      defn = described_class.new(
        name: "test",
        contains_type: "string",
        contains_ref: "#/$defs/Foo",
        pattern_properties: { "^S_" => { "type" => "string" } },
        not_type: "integer",
        composition_variants: %w[string integer],
      )
      parsed = JSON.parse(defn.to_json)
      expect(parsed["containsType"]).to eq("string")
      expect(parsed["containsRef"]).to eq("#/$defs/Foo")
      expect(parsed["patternProperties"]).to eq("^S_" => { "type" => "string" })
      expect(parsed["notType"]).to eq("integer")
      expect(parsed["compositionVariants"]).to eq(%w[string integer])
    end

    it "serializes links" do
      link = Lutaml::Jsonschema::Spa::SpaLink.new(
        title: "Create",
        href: "/items",
        http_method: "POST",
      )
      defn = described_class.new(name: "test", links: [link])
      parsed = JSON.parse(defn.to_json)
      expect(parsed["links"].length).to eq(1)
      expect(parsed["links"].first["title"]).to eq("Create")
    end

    it "round-trips through JSON" do
      defn = described_class.new(
        name: "Address",
        title: "Address",
        type: "object",
        required: %w[street city],
        additional_properties: false,
      )
      reparsed = described_class.from_json(defn.to_json)
      expect(reparsed.name).to eq("Address")
      expect(reparsed.type).to eq("object")
      expect(reparsed.required).to eq(%w[street city])
      expect(reparsed.additional_properties).to eq(false)
    end
  end
end
