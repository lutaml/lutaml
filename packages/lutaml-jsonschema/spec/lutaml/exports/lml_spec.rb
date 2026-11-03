# frozen_string_literal: true

require "spec_helper"
# the round-trip example parses the generated model back with the org's
# LML toolchain; required up front (lutaml-uml defines a top-level
# SchemaSet, so this file's constants stay fully qualified)
require "lutaml/lml"

RSpec.describe Lutaml::Jsonschema::Exports::Lml do
  def schema_set_from(hash, name: "demo")
    set = Lutaml::Jsonschema::SchemaSet.new
    set.add(name, Lutaml::Jsonschema::Schema.from_json(Yeptris::JSON.dump(hash)))
    set
  end

  def render(hash)
    described_class.new(schema_set_from(hash)).render
  end

  def definition_set(definitions)
    schema_set_from({
                      "type" => "object",
                      "definitions" => definitions,
                    })
  end

  def render_definitions(definitions)
    described_class.new(definition_set(definitions)).render
  end

  it "renders object definitions as classes with typed attributes" do
    output = render_definitions(
      "person" => {
        "type" => "object",
        "required" => %w[name],
        "properties" => {
          "name" => { "type" => "string" },
          "age" => { "type" => "integer" },
          "score" => { "type" => "number" },
          "active" => { "type" => "boolean" },
        },
      },
    )

    expect(output).to include("class person {")
    expect(output).to include("attribute name {\n    type String\n    cardinality 1\n  }")
    expect(output).to include("attribute age {\n    type Integer\n    cardinality 0..1\n  }")
    expect(output).to include("attribute score {\n    type Float")
    expect(output).to include("attribute active {\n    type Boolean")
  end

  it "emits cardinality 1 only for required members, 0..1 otherwise" do
    output = render_definitions(
      "thing" => {
        "type" => "object",
        "required" => %w[must],
        "properties" => {
          "must" => { "type" => "string" },
          "may" => { "type" => "string" },
        },
      },
    )

    expect(output.scan("cardinality 1\n").size).to eq(1)
    expect(output).to include("cardinality 0..1")
  end

  it "maps date formats to LML temporal primitives" do
    output = render_definitions(
      "event" => {
        "type" => "object",
        "properties" => {
          "at" => { "type" => "string", "format" => "date-time" },
          "on" => { "type" => "string", "format" => "date" },
          "home" => { "type" => "string", "format" => "uri" },
        },
      },
    )

    expect(output).to include("type DateTime")
    expect(output).to include("type Date\n")
    expect(output).to include("type Uri")
  end

  it "renders enum definitions as enum blocks" do
    output = render_definitions(
      "state" => { "type" => "string", "enum" => %w[active provisioning deprovisioned] },
    )

    expect(output).to include(<<~LML.strip)
      enum state {
        active
        provisioning
        deprovisioned
      }
    LML
  end

  it "renders enum-valued properties as inline value sets" do
    output = render_definitions(
      "job" => {
        "type" => "object",
        "properties" => {
          "state" => { "enum" => %w[queued running] },
        },
      },
    )

    expect(output).to include("values { queued, running }")
  end

  it "types a $ref to a top-level definition as an association" do
    output = render_definitions(
      "team" => { "type" => "object", "properties" => { "name" => { "type" => "string" } } },
      "membership" => {
        "type" => "object",
        "properties" => { "team" => { "$ref" => "#/definitions/team" } },
      },
    )

    expect(output).to include("attribute team {\n    type team\n    cardinality 0..1\n  }")
  end

  it "resolves $refs into nested definitions to the target's type" do
    output = render_definitions(
      "account" => {
        "type" => "object",
        "properties" => {
          "created_at" => { "$ref" => "#/definitions/account/definitions/created_at" },
        },
        "definitions" => {
          "created_at" => { "type" => "string", "format" => "date-time" },
        },
      },
    )

    expect(output).to include("type DateTime")
  end

  it "carries arrays of definitions as 0..n or 1..n associations" do
    output = render_definitions(
      "dyno" => { "type" => "object", "properties" => { "id" => { "type" => "string" } } },
      "formation" => {
        "type" => "object",
        "required" => %w[dynos],
        "properties" => {
          "dynos" => {
            "type" => "array",
            "minItems" => 1,
            "items" => { "$ref" => "#/definitions/dyno" },
          },
          "tags" => {
            "type" => "array",
            "items" => { "type" => "string" },
          },
        },
      },
    )

    expect(output).to include("type dyno\n    cardinality 1..n")
    expect(output).to include("type String\n    cardinality 0..n")
  end

  it "treats nullable types as optional regardless of required" do
    output = render_definitions(
      "account" => {
        "type" => "object",
        "required" => %w[identity_provider],
        "properties" => {
          "identity_provider" => { "type" => %w[object null] },
        },
      },
    )

    expect(output).to include("type Hash\n    cardinality 0..1")
  end

  it "keeps descriptions, escaping LML string content" do
    output = render_definitions(
      "doc" => {
        "type" => "object",
        "properties" => {
          "quote" => { "type" => "string", "description" => 'says "hi"\nbye' },
        },
      },
    )

    expect(output).to include('description "says \\"hi\\"\\\\nbye"')
  end

  it "renders boolean-schema members as comments and true as untyped" do
    output = render_definitions(
      "mixed" => {
        "type" => "object",
        "properties" => {
          "anything" => true,
          "nothing" => false,
        },
      },
    )

    expect(output).to include("  anything")
    expect(output).to include("// nothing: no value allowed")
  end

  it "produces LML the lutaml-lml parser accepts (real-world corpus)" do
    set = Lutaml::Jsonschema::SchemaSet.load_from_files(
      fixture_path("heroku.json"), fixture_path("interagent_simple.json")
    )
    output = described_class.new(set).render
    doc = Lutaml::Lml.parse_document(StringIO.new(output))

    names = doc.classes.map(&:name)
    expect(names).to include("account", "dyno", "identity_provider")
    expect(names.size).to be > 50

    account = doc.classes.find { |c| c.name == "account" }
    attribute_names = account.attributes.map(&:name)
    expect(attribute_names).to include("created_at", "email", "identity_provider")
  end
end
