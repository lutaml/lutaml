# frozen_string_literal: true

require "spec_helper"

RSpec.describe Lutaml::Jsonschema::ReferenceResolver do
  let(:resolver) { described_class.new }

  def parse(hash)
    Lutaml::Jsonschema::Schema.from_json(Yeptris::JSON.dump(hash))
  end

  describe "JSON Pointer (RFC 6901)" do
    let(:schema) do
      parse(
        "definitions" => {
          "a/b" => { "type" => "string" },
          "c~d" => { "type" => "integer" },
          "with space" => { "type" => "boolean" },
        },
      )
    end

    it "unescapes ~1 to /" do
      expect(resolver.resolve("#/definitions/a~1b", schema).type).to eq("string")
    end

    it "unescapes ~0 to ~" do
      expect(resolver.resolve("#/definitions/c~0d", schema).type).to eq("integer")
    end

    it "decodes ~01 as the literal ~1" do
      schema = parse("definitions" => { "x~1" => { "type" => "string" } })
      expect(resolver.resolve("#/definitions/x~01", schema).type).to eq("string")
    end

    it "returns boolean schema targets verbatim" do
      schema = parse("$defs" => { "flag" => false })
      expect(resolver.resolve("#/$defs/flag", schema)).to be(false)
    end

    it "percent-decodes fragment segments" do
      expect(resolver.resolve("#/definitions/with%20space", schema).type)
        .to eq("boolean")
    end

    it "navigates array indices in composition keywords" do
      schema = parse(
        "allOf" => [{ "type" => "string" }, { "type" => "integer" }],
      )

      expect(resolver.resolve("#/allOf/1", schema).type).to eq("integer")
      expect(resolver.resolve("#/allOf/9", schema)).to be_nil
    end

    it "resolves '#' to the root schema" do
      expect(resolver.resolve("#", schema)).to equal(schema)
    end

    it "follows a $ref encountered at the pointer target" do
      schema = parse(
        "definitions" => {
          "alias" => { "$ref" => "#/definitions/real" },
          "real" => { "type" => "string" },
        },
      )

      expect(resolver.resolve("#/definitions/alias", schema).type).to eq("string")
    end

    it "terminates on cyclic ref chains instead of recursing" do
      schema = parse(
        "definitions" => {
          "a" => { "$ref" => "#/definitions/b" },
          "b" => { "$ref" => "#/definitions/a" },
        },
      )

      expect(resolver.resolve("#/definitions/a", schema)).to be_nil
    end

    it "follows $dynamicRef through the dynamic anchor index" do
      schema = parse(
        "definitions" => {
          "node" => { "$dynamicAnchor" => "node", "type" => "object" },
          "alias" => { "$dynamicRef" => "#node" },
        },
      )

      expect(resolver.resolve("#/definitions/alias", schema).type)
        .to eq("object")
    end

    it "follows $recursiveRef '#' to the root schema" do
      schema = parse(
        "definitions" => {
          "alias" => { "$recursiveRef" => "#" },
        },
      )

      expect(resolver.resolve("#/definitions/alias", schema)).to equal(schema)
    end

    it "returns nil for unresolvable pointers" do
      expect(resolver.resolve("#/definitions/missing", schema)).to be_nil
    end
  end

  describe "anchors" do
    it "resolves $anchor fragments anywhere in the document tree" do
      schema = parse(
        "properties" => {
          "thing" => { "$anchor" => "thing", "type" => "string" },
        },
      )

      expect(resolver.resolve("#thing", schema).type).to eq("string")
    end

    it "resolves draft-04 legacy id anchor fragments" do
      schema = parse(
        "properties" => {
          "legacy" => { "id" => "#legacy", "type" => "integer" },
        },
      )

      expect(resolver.resolve("#legacy", schema).type).to eq("integer")
    end

    it "returns nil for unknown anchors" do
      schema = parse("type" => "object")

      expect(resolver.resolve("#nope", schema)).to be_nil
    end
  end

  describe "remote refs" do
    let(:target) { parse("type" => "string") }
    let(:resolver) { described_class.new("other.json" => target) }

    it "resolves a bare file ref from the schema map" do
      expect(resolver.resolve("other.json")).to equal(target)
    end

    it "resolves a file ref with a pointer fragment" do
      target = parse("definitions" => { "x" => { "type" => "integer" } })
      resolver = described_class.new("other.json" => target)

      expect(resolver.resolve("other.json#/definitions/x").type).to eq("integer")
    end

    it "resolves a file ref with an anchor fragment" do
      target = parse("properties" => { "p" => { "$anchor" => "a", "type" => "string" } })
      resolver = described_class.new("other.json" => target)

      expect(resolver.resolve("other.json#a").type).to eq("string")
    end
  end

  describe "$id resolution (RFC 3986)" do
    it "resolves a ref to a nested absolute $id" do
      schema = parse(
        "properties" => {
          "p" => { "$id" => "https://example.org/person.json",
                   "type" => "object" },
        },
      )

      expect(resolver.resolve("https://example.org/person.json", schema).type)
        .to eq("object")
    end

    it "joins relative $ids to the root base and accepts ./ prefixes" do
      schema = parse(
        "$id" => "https://example.org/root.json",
        "properties" => {
          "p" => { "$id" => "person.json", "type" => "integer" },
        },
      )

      expect(resolver.resolve("https://example.org/person.json", schema).type)
        .to eq("integer")
      expect(resolver.resolve("person.json", schema).type).to eq("integer")
      expect(resolver.resolve("./person.json", schema).type).to eq("integer")
    end

    it "resolves nested $ids relative to the nearest enclosing $id" do
      schema = parse(
        "$id" => "https://example.org/root.json",
        "properties" => {
          "a" => { "$id" => "sub/a.json", "type" => "string" },
          "b" => { "$id" => "sub/b.json", "type" => "integer" },
        },
      )

      expect(resolver.resolve("https://example.org/sub/b.json", schema).type)
        .to eq("integer")
      expect(resolver.resolve("sub/a.json", schema).type).to eq("string")
    end

    it "prefers the schema-set name map over $id matches" do
      target = parse("type" => "string")
      resolver = described_class.new("other.json" => target)
      schema = parse(
        "properties" => { "p" => { "$id" => "other.json",
                                   "type" => "integer" } },
      )

      expect(resolver.resolve("other.json", schema)).to equal(target)
    end
  end
end
