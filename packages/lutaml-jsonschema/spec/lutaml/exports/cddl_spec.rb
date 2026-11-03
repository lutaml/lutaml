# frozen_string_literal: true

require "spec_helper"

RSpec.describe Lutaml::Jsonschema::Exports::Cddl do
  def schema_set_from(hash, name: "demo")
    set = Lutaml::Jsonschema::SchemaSet.new
    set.add(name, Lutaml::Jsonschema::Schema.from_json(Yeptris::JSON.dump(hash)))
    set
  end

  def render(hash)
    described_class.new(schema_set_from(hash)).render
  end

  it "renders an object with required and optional properties" do
    output = render(
      "type" => "object",
      "required" => %w[name],
      "properties" => {
        "name" => { "type" => "string" },
        "age" => { "type" => "integer" },
      },
    )

    expect(output).to include("demo = { name: text, ?age: int }")
  end

  it "renders enums as literal unions and consts as single literals" do
    expect(render(
             "type" => "object",
             "required" => %w[status kind],
             "properties" => {
               "status" => { "enum" => %w[a b] },
               "kind" => { "const" => "fixed" },
             },
           )).to include(%({ status: "a" / "b", kind: "fixed" }))
  end

  it "renders arrays, including prefixItems tails" do
    single = render("type" => "array", "items" => { "type" => "string" })
    expect(single).to include("demo = [* text]")

    tuple = render(
      "type" => "array",
      "prefixItems" => [{ "type" => "string" }],
      "items" => { "type" => "integer" },
    )
    expect(tuple).to include("demo = [text, * int]")
  end

  it "renders draft-04 tuple items and boolean forms" do
    tuple = render(
      "type" => "array",
      "items" => [{ "type" => "string" }, { "type" => "integer" }],
      "additionalItems" => false,
    )
    expect(tuple).to include("demo = [text, int]")

    expect(render("type" => "array", "items" => true))
      .to include("demo = [* any]")
    expect(render("type" => "array", "items" => false))
      .to include("demo = []")
  end

  it "renders boolean schemas as any" do
    output = render(
      "type" => "object",
      "required" => ["flag"],
      "properties" => { "flag" => true },
    )

    expect(output).to include("flag: any")
  end

  it "renders boolean prefixItems entries" do
    tuple = render(
      "type" => "array",
      "prefixItems" => [true, { "type" => "string" }, false],
    )

    expect(tuple).to include("demo = [any, text]")
  end

  it "resolves $ref members to their definition group names" do
    output = render(
      "definitions" => {
        "tag" => { "type" => "object", "required" => ["id"],
                   "properties" => { "id" => { "type" => "string" } } },
      },
      "type" => "object",
      "required" => ["tag"],
      "properties" => {
        "tag" => { "$ref" => "#/definitions/tag" },
      },
    )

    expect(output).to include("tag = { id: text }")
    expect(output).to include("demo = { tag: tag }")
  end

  it "quotes keys that are not CDDL identifiers" do
    expect(render(
             "type" => "object",
             "required" => ["user-name"],
             "properties" => { "user-name" => { "type" => "string" } },
           )).to include(%({ "user-name": text }))
  end

  it "emits rest types for additionalProperties" do
    expect(render(
             "type" => "object",
             "properties" => { "a" => { "type" => "string" } },
             "additionalProperties" => true,
           )).to include("* text => any")
    expect(render(
             "type" => "object",
             "properties" => { "a" => { "type" => "string" } },
             "additionalProperties" => false,
           )).not_to include("=>")
  end

  it "renders a real fixture without raising" do
    set = Lutaml::Jsonschema::SchemaSet.load_from_files(
      File.expand_path("../../fixtures/person.json", __dir__),
    )
    output = described_class.new(set).render

    expect(output).to include("person = {")
  end

  # RFC 8610 round trip: the generated rules must be accepted by the
  # reference CDDL parser (real-world corpus, the done-when bar).
  it "produces CDDL the RFC 8610 reference parser accepts (real-world corpus)" do
    require "cddl"

    set = Lutaml::Jsonschema::SchemaSet.load_from_files(
      fixture_path("heroku.json"),
      fixture_path("interagent_simple.json"),
      fixture_path("person.json"),
    )
    output = described_class.new(set).render

    expect { CDDL::Parser.new(output) }.not_to raise_error
  end
end
